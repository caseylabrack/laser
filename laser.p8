pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- zaag
-- casey labrack

-- todo:
--  doom-style avatar in corner
--  zoids,flaurs,
--  gamescreen shows bests score 
--  timing or lap based enemy? (boss?)

p = {x=80,y=30,dx=0,dy=0,
					a=.75,t=.25,rt=.05,r=3,friction=.92,
					hop=25,charge=0,fullcharge=230,
					enabled=false,
					thrusting=false,
					gun=0,gunfull=120,gunfail=false,gunfailtick=0,
					flipready=10,fliplast=0,}
dmg={ 
	{roid=2,flower=2,bomb=60},--easy
	{roid=2,flower=2,bomb=60},--normal
	{roid=1,flower=1,bomb=30},--hard
}
lz= {} --lasers
zs= {} --safe zones
hs= {} --homing bombs
as= {} --animations (coroutines)
a2= {} --animations in draw phase
fs= {} --flowers
rs= {} --roids
b = {x=0,y=0,dx,dy,a=0,r=2,speed=5,enabled=false,parts={}}
inner = {x=64,y=64,r=6}
outer = {x=64,y=64,r=63,enabled=true}
lvl=1
mulligans=1
extralives=mulligans
mulmsg={ --titlescreen mulligan description
"(3 mulligans, 2x dmg)",
"(1 mulligan, 2x dmg)",
"(1 mulligan, 1x dmg)",
}
diffmsg={--titlescreen difficulty description
"difficulty: relaxed",
"difficulty: recommended",
"difficulty: show-off",
}
difficulty=1--1 easy,2 med,3 hard
tick=0
state="title"
cp=dp--current pallete
sleep=0
shake=0
fire_btn=❎
thrust_btn=🅾️
screenshake=true
--coroutines:
wipe=nil
blink=nil
title=nil
dethmsg=nil

dethmsgs={
"another oopsie i see",
"what, am i made out of ships?",
"zigged when you shoulda zaaged",
"well, the ejector seat works",
"i was told you knew how to fly",
}

tips={
	{"remember to take","15 minute breaks!"},
	{"zaag is a fun game"},
	{"ship defenses have","an initial charge time.","i know, i'm sorry."},
	{"for safety in the tau,","ships fire only one","bullet at a time"},
	{"very close range shots","= very fast rate of fire"},
	{"quick flip (⬇️) is","faster than doing a 180"},
	{"the tele takes a","while to charge.","good thing you're","good at dodging"},
	{"some preferences","(screen shake toggle","and button swaps)","in the pause menu"},
}

function _init()
	cartdata("caseylabrack_zaag")
	local swapped=dget(0)==1
	fire_btn  = (not swapped) and ❎ or 🅾️ 
	thrust_btn= (not swapped) and 🅾️ or ❎
	screenshake=dget(1)==1
	difficulty=dget(2)
	difficulty=difficulty==0 and 2 or difficulty
	title=cocreate(title_setup)
	menuitem(1, "swap action btns", btns_toggle)
	menuitem(2, "screenshake:"..(screenshake==1 and "on" or "off"), screenshake_toggle)
end

function btns_toggle()
	if fire_btn==❎ then	
		fire_btn=🅾️ thrust_btn=❎
		dset(0,1)
	else	
		fire_btn=❎ thrust_btn=🅾️
		dset(0,0)
	end 
end

function screenshake_toggle()
	screenshake=not screenshake
	menuitem(2, screenshake==true and "screenshake:on" or "screenshake:off",screenshake_toggle)
	dset(1,screenshake==true and 1 or 0)
	return true
end

function _update()
tick+=1

-- do animations
for a in all(as) do
	if costatus(a)!="dead" then assert(coresume(a))
	else del(as,a) end
end

if state=="setup" or state=="wipe" then
	return
end

--pauses most game logic for a number of frames
if sleep>0 then
	sleep-=1
	return
end

if p.enabled then
	p.charge+=1 p.gun=min(p.gun+1,p.gunfull)
	if btn(➡️) then p.a=p.a-p.rt end
	if btn(⬅️) then p.a=p.a+p.rt end
	if btn(⬇️) then
		if tick-p.fliplast>p.flipready then
		 p.a+=.5
		 p.fliplast=tick
	 end
	end
	if btn(thrust_btn) then
		p.dx+=cos(p.a)*p.t
		p.dy+=sin(p.a)*p.t
		if not p.thrusting then
			p.thrusting=true
			sfx(2)
		end
	else
		sfx(2,-2)
		p.thrusting=false
	end
	if btn(⬆️) and p.charge>p.fullcharge then
		local x1,y1=p.x,p.y
		local dur=8
		p.x+=cos(p.a)*p.hop
		p.y+=sin(p.a)*p.hop
		p.thrusting=false
		blink=cocreate(blink_anim)
		coresume(blink,x1,y1,p.x,p.y,dur)
		p.charge=0
		sleep=dur
		sfx(22)
	end
	if btn(fire_btn) and not b.enabled then
		if p.gun==p.gunfull then
			b.enabled=true
			b.x=p.x b.y=p.y b.a=p.a
			b.dx=cos(b.a)*b.speed b.dy=sin(b.a)*b.speed
			sfx(20)
--		sfx(25)
		else
			if tick-p.gunfailtick>2 then
				p.gunfail=true
				sfx(12)
				p.gunfailtick=tick
			end
		end
	end
end
p.x=p.x+p.dx
p.y=p.y+p.dy
p.dx*=p.friction
p.dy*=p.friction

--flowers
for f in all(fs) do
	f.tick+=1
	for l in all(f) do --each leaf
		if p.enabled and touching(p,l) then died(l) end
		l.growcount+=1
		if l.growcount>f.growgoal and l.r<12 then --grow
			if not touching(l,inner) then
				l.r+=1
				l.growcount=0
			end
		end
	end
	if f.tick%150==0 and #f<f.max then --bud
		local couldbuds=filter(function(x) return x.r>=12 end, f)
		if #couldbuds>0 then
			local k={}
			local ang=0
			local colliding=true
			local i=0
			local l={}
			while colliding and i<100 do
				i+=1
				l=rnd(couldbuds)
				ang=rnd(1)
				k.x,k.y=l.x+cos(ang)*l.r,l.y+sin(ang)*l.r
				i2=0
				while distt(k,inner)>63 and i2<100 do
					i2+=1
					ang=rnd(1)
					k.x,k.y=l.x+cos(ang)*l.r,l.y+sin(ang)*l.r
				end
				k.r=8
				colliding=false
				for m in all(f) do
					if m~=l then
						if touching(m,k) then
							colliding=true
							break
						end
					end
				end
			end
			if i<100 then
--				if distt(k,inner)<62 then
					k.r=2	k.growcount=0 k.hit=-100
					add(f,k)
--				end
			end
		end
	end
end

-- laser move
for l in all(lz) do
	l.a-= l.speed
	l.x = 64 + cos(l.a) * 63
	l.y = 64 + sin(l.a) * 63
	for z in all(l.parts) do
		z.x+=z.dx z.y+=z.dy
		z.dx*=.95 z.dy*=.95
		if tick-z.tick>5 then
			del(l.parts,z)
		end
	end
		local z={}
		z.x,z.y=l.x,l.y
		z.a=l.a+.5+rndr(-.25,.25)
		z.dx=cos(z.a)*rndr(1,2)
		z.dy=sin(z.a)*rndr(1,2)
		z.tick=tick
		add(l.parts,z)
--	end
end

-- safe zones
for z in all(zs) do
	if z.state=="idle" then
		if touching(p,z) then
			z.state="shrinking"
		end
	elseif z.state=="shrinking" then
		z.t-=z.speed
		if z.t<2 then 
			z.state="moving"
			z.start=z.a
			z.dist=rnd(2)
			z.mstart=tick
			z.mdur=180
		end
	elseif z.state=="moving" then
		local pct=min(1,(tick-z.mstart)/z.mdur)
		if pct<1 then
			pct=easeinoutquart(pct)
			z.a=z.start+z.dist*pct
			z.x,z.y=64+cos(z.a)*63,64+sin(z.a)*63
		else
			z.t=32
			z.state="idle"
		end
	end
end

--homing bomb move
for h in all(hs) do
	if h.enabled then
		local a=atan2(p.x-h.x+rnd(4)-2,p.y-h.y+rnd(4)-2)
		h.dx+=cos(a)*h.t	 h.dy+=sin(a)*h.t
		h.frametick+=1
	else
		h.timer-=1
		if h.timer<0 then h.enabled=true end
--		sfx(3)
	end
	h.dx*=.97 h.dy*=.97
	h.x+=h.dx	h.y+=h.dy
	local a2=atan2(h.x-64,h.y-64)
	if dist(h.x,h.y,64,64)<8 then
		h.x=inner.x+cos(a2)*8
		h.y=inner.y+sin(a2)*8
	end
	if dist(h.x,h.y,64,64)>63 then
		h.x=64+cos(a2)*63
		h.y=64+sin(a2)*63
	end
end

local ang=atan2(p.x-64,p.y-64)

-- player vs outside wall
if dist(p.x,p.y,64,64) > 63 then
	p.x=64+cos(ang)*63
	p.y=64+sin(ang)*63
end

-- player vs inside wall
if touching(inner,p) then
	p.x=64+cos(ang)*8
	p.y=64+sin(ang)*8
end

if p.enabled then
	-- player vs. obstacles
	for v in all(rs) do
		if (touching(p,v)) died(v)
	end

	--player vs. homing bombs
	for h in all(hs) do
		if (touching(p,h)) died(h)
	end
end

--laser/player collision
if p.enabled then
	local d=dist(p.x,p.y,64,64)
	local vulnerable=true
	for z in all(zs) do
		if z.state~="moving" and touching(p,z) then vulnerable=false break end
	end
	if vulnerable then
		for l in all(lz) do
			if touching(p,{x=64+cos(l.a)*d,y=64+sin(l.a)*d,r=0}) then
				died(l)
			end
		end
	end
end

--bouncing around
for v in all(rs) do
	if not v.enabled then goto continue end
	v.x=v.x+v.dx
	v.y=v.y+v.dy
	if dist(v.x,v.y,64,64)>63 then
		local a=atan2(v.x-64,v.y-64)
		local x=64+cos(a)*63
		local y=64+sin(a)*63
		v.x=x v.y=y
		local inc=atan2(v.dx,v.dy)+.5 --incidence
		local def=a+a-inc
		local mag=dist(0,0,v.dx,v.dy)
		v.dx=cos(def)*mag
		v.dy=sin(def)*mag
	end
	if dist(v.x,v.y,64,64)<4+v.r then
		local a=atan2(v.x-64,v.y-64)
		local x=64+cos(a)*(4+v.r)
		local y=64+sin(a)*(4+v.r)
		v.x=x v.y=y
		local inc=atan2(v.dx,v.dy)+.5 --incidence
		local def=a+a-inc
		local mag=dist(0,0,v.dx,v.dy)
		v.dx=cos(def)*mag
		v.dy=sin(def)*mag
	end
	::continue::
end

--bullet
for bp in all(b.parts) do
	bp.t-=1
	bp.x+=bp.dx or 0
	bp.y+=bp.dy or 0
	if bp.t<0 then
		del(b.parts,bp)
	end
end
if b.enabled then
	local x1=b.x
	local y1=b.y
	for i=1,5 do
		b.x=x1+b.dx*i/5
		b.y=y1+b.dy*i/5
		add(b.parts,
		{x=b.x,y=b.y,t=rnd(3)})
		for f in all(fs) do --flowers
			for l in all(f) do --leaves
				if touching(b,l) then
					b.enabled=false sfx(20,-2)
					b:splash()
--					sfx(24)
					sfx(21)
					l.r-=dmg[difficulty].flower
					l.growcount=0
					l.hit=tick
					if l.r<3 then
						shake+=2
						del(f,l)
						if #f==0 then del(fs,f) end
					end
					goto donebullet
				end
			end
		end
		for v in all(rs) do --roids
			if touching(b,v) then
				b.enabled=false sfx(20,-2)
				b:splash()
				sfx(21)
				local oldr=v.r
				v.r-=dmg[difficulty].roid
				v.hit=tick
				if v.r<3 then	
					shake+=1.1
					local z=cocreate(rsplode)
					coresume(z,v.x,v.y,oldr,v.dx,v.dy)
					add(a2,z)
					del(rs,v) 
				end
				goto donebullet
			end
		end
		for h in all(hs) do --homing
			if touching(h,b) then
				b.enabled=false sfx(20,-2)
				b:splash()
--				sfx(21)
				h.enabled=false
				h.timer=dmg[difficulty].bomb
				h.dx+=b.dx/4	h.dy+=b.dy/4
				goto donebullet
			end
		end
		if touching(inner,b) or distt(inner,b)>63 then
			b.enabled=false sfx(20,-2)
			b:splash()
--			sfx(25)
--			sfx(21)
			goto donebullet
		end
	end
end
::donebullet::

--level win
if #rs==0 and #fs==0 and p.enabled and state=="running" then
	state="wiping"
	extralives=mulligans
	sfx(2,-2)
--	p.enabled=false
	p.thrusting=false
	lvl+=1
	if lvl>#lvls then lvl=1 end
	wipe=cocreate(wipe_anim)
	state="wipe"
end
end

function died(cause)
	if state~="running" then return end
	sfx(2,-2)
	sfx(13)
	shake+=4
	p.enabled=false
	p.thrusting=false
	local d=cocreate(deathparticles)
	coresume(d,cause)
	add(a2,d)
	extralives-=1
	state="death"
	local a=cocreate(death)
	coresume(a,15,30)
	add(as,a)
end

function _draw()
cls()

if shake > 1 then
	if screenshake then
		camera()
		local a=rnd()
		camera(cos(a)*shake,sin(a)*shake)
	end
	shake*=.75
else
	camera()
end

pal(cp)

--do animations
for z in all(a2) do
	if costatus(z)!="dead" then assert(coresume(z))
	else del(a2,z) end
end

--safe zone
for z in all(zs) do
	if z.state=="idle" or z.state=="shrinking" then
--	fillp(░)
	fillp(32125)
--	fillp(0b0101101001011010)
	circfill(z.x,z.y,z.r,0x01)
--	circfill(z.x,z.y,z.r,0x0c)
	fillp()
	circfill(z.x,z.y,z.r-z.t,0)
	circ(z.x,z.y,z.r,1)
		
	end
	spr(5,z.x-4,z.y-4)
end

pal()
if outer.enabled then
	circ(outer.x,outer.y,outer.r,6)
--	circle(outer.x,outer.y,outer.r,6)
end
pal(cp)

--laser
for l in all(lz) do
	color(8)
	line(64,64,l.x,l.y,8)
	if rnd(1)>.1 then
		circfill(l.x,l.y,rnd(2),8)
	end
	for z in all(l.parts) do
		pset(z.x,z.y,8)
	end
end

--flowers
for f in all(fs) do
	for l in all(f) do
			fillp(ˇ)
			circfill(l.x,l.y,l.r,tick-l.hit>30 and 11 or 3)
			fillp()
	end
	for l in all(f) do
			spr(20,l.x-4,l.y-4)
	end
end

--emitter
if state~="dead" then
	circfill(64,64,inner.r,0)
	circ(64,64,inner.r,6)
--	circ(64,64,inner.r,#lz==0 and 6 or 8)
--	circ(64,64,1,8)
--	if #lz==0 then circ(64,64,1,2) end
end

--homing bombs
for h in all(hs) do
	if h.enabled then
	spr((flr(h.frametick%8)/2)+16,h.x-4,h.y-4)
	else
	spr(23,h.x-4,h.y-4)
	end
end

--player
if p.enabled then
	local lines,fire,prow=p:coords()
	if p.thrusting then
		circfill(fire.x,fire.y,1,rndr(8,11))
	end
	for l in all(lines) do
		line(l.x1,l.y1,l.x2,l.y2,7)
	end
end

if blink and costatus(blink)~="dead" then coresume(blink) end

-- roids
for v in all(rs) do
	circ(v.x,v.y,v.r,tick-v.hit>2 and 9 or 7)
	spr(2,v.x-4,v.y-4)
	local a=atan2(v.dx,v.dy)-.5
	local x=v.x+cos(a)*v.r
	local y=v.y+sin(a)*v.r
	local m=dist(0,0,v.dx,v.dy)*3
	line(x,y,x+cos(a)*m,y+sin(a)*m)
end

--bullet
if b.enabled then
	line(b.x,b.y,b.x-b.dx,b.y-b.dy,12)
end

for bp in all(b.parts) do
	pset(bp.x,bp.y,12)
end

if wipe and costatus(wipe)~="dead" then coresume(wipe) end

pal()

if state=="running" then
	--gun countdown
	local x,y,x2,y2=97,0,127,8
	local pct=min(p.gun/p.gunfull,1)
	local f=p.gun<p.gunfull and 3 or 11
	if p.gunfail then
 	f=8
		p.gunfail=false
	end
	clip(x,y,(x2-x)*pct+1,y2+1)
	rect(x,y,x2,y2,f)
	print("gun rdy",x+2,y+2,f)

	--hop countdown
	local f=p.charge<p.fullcharge and 1 or 12
 local pct=min(p.charge/p.fullcharge,1)
	local x,x2,y,y2=109,127,10,18
	clip(x,y,(x2-x)*pct+1,10)
	rect(x,y,x2,y2,f)
	clip()
	print("tele",x+2,y+2,f)
end

if state=="running" or state=="setup" then
	print("tau "..lvl,0,2,7)
	for i=1,extralives do
		spr(22,i*6-6,10)
	end
end

--for i=1,1000 do
----	local x,y=rnd(127),rnd(127)
--	local d,a=rnd(64),rnd()
--	local x,y=63+cos(a)*d,63+sin(a)*d
--	local c=pget(x,y)
--	pset(x+rnd(2),y+rnd(2),c)
--end

--print(stat(1),0,120,7)

if state=="death" then
	if outer.enabled then
--	circ(outer.x,outer.y,outer.r,6)
	circle(outer.x,outer.y,outer.r,6)
end

end

if title and costatus(title)~="dead" then coresume(title) end

end

-->8
--levels
lvls={
--	{roids=5},
--	{flowers=1,lasers=1,safezone=true},
	{roids=4,lasers=1},
	{roids=6,lasers=1,safezone=true},
	{roids=4,lasers=1,flowers=2},
	{roids=5,lasers=1,flowers=3},
	{roids=6,lasers=1,flowers=4,safezone=true},
	{roids=4,bomb=true},
	{roids=4,flowers=3,bomb=true},
	{roids=3,flowers=2,bomb=true,lasers=1,safezone=true},
	{roids=10,lasers=2,safezone=true},
}

function wipe_anim()
--	outer.enabled=false	
	local start=tick
	while tick-start<30 do
		if tick-start==15 then p.enabled=false end
		local pct=(tick-start)/30
--		pct=easeoutexpo(pct)
		pct=easeinexpo(pct)
		local r=inner.r+(63-inner.r)*pct
		circfill(64,64,r,0)
		circ(64,64,r,6)
		outer.r=63+pct*50
		yield()
	end
	circfill(64,64,63,0)
	circ(64,64,63,6)
	lz={}	zs={} hs={} rs={} fs={} b.enabled=false b.parts={}
	outer.enabled=true
	outer.r=63
	add(as,cocreate(spawn))
end

function spawn()
	state="setup"
	i=10 c=15 p.x=64 p.y=32 p.dx=0 p.dy=0 p.charge=0 p.a=-.1 p.gun=0
	--player entering animation
	local enteranim=cocreate(penter)
	coresume(enteranim,p.x,p.y,c)
	add(a2,enteranim)
	while c>0 do c-=1 yield() end
	p.enabled=true

	--spawn each unit type in random order
	for unit,num in pairs(lvls[lvl]) do
		c=i --countdown spawn interval
		while true do
			c-=1
			if c>0 then goto continue end
			if unit=="roids" then
				local r={}
				local a=aim_away(.25,.25)
				local d=rnd(64-24)+12
				r.x=64+cos(a)*d r.y=64+sin(a)*d
				local to_p=atan2(p.x-r.x,p.y-r.y)
				local a2=aim_away(to_p,.25)
				local spd=rnd(1.25)+.5
				r.dx=cos(a2)*spd r.dy=sin(a2)*spd
				r.r=3+rnd(8-3) r.enabled=true
				r.hit=-10
				add(rs,r)
				sfx(6)
				if #rs==num then break end
			end
			if unit=="safezone" then
				local z = {a=0,r=32,x=0,y=0,t=32,shrinking=false,speed=.25}
				z.a=rnd(1)
				z.x=64+cos(z.a)*63
				z.y=64+sin(z.a)*63
				z.state="idle"
				add(zs,z)
				sfx(10)
				break
			end
			if unit=="lasers" then
				local a=(1/num)*#lz+.1
				add(lz,{a=a,x=64+cos(a)*63,y=64+sin(a)*63,speed=.005,parts={index=0}})
				sfx(7)
				if #lz==num then break end
			end
			if unit=="bomb" then
				local a=aim_away(.25,.6)
				local d=rnd(64-24)+12
				add(hs,{x=64+cos(a)*d,y=64+sin(a)*d,
								r=3,dx=0,dy=0,t=.05,
								enabled=true,timer=0,
								frametick=0})
				sfx(9)
				break
			end
			if unit=="flowers" then
				local f={}
				f.tick=flr(rnd(10))
				f.max=12
				f.growgoal=30 --grow rate
				f.br=250 --bud rate
				local r={}
				local d=12+rnd(63-24)
				local a=aim_away(.25,.25)
				r.x=64+cos(a)*d r.y=64+sin(a)*d r.r=9
				r.growcount=-rnd(30) r.hit=-100
				add(f,r)
				add(fs,f)
				sfx(8)
				if #fs==num then break end
			end
			c=i
			::continue::
			yield()
		end
	end
	c=i
	while c>0 do c-=1 yield() end
	state="running"
end

function death(delay,duration)
	yield()
	while delay>0 do
		delay-=1
		yield()
	end
	local start=tick
	while tick-start<duration do
		local pct=(tick-start)/duration
		cp=bwp[ceil(pct*#bwp)]
		yield()
	end
	lz={}	zs={} hs={} rs={} fs={} b.enabled=false b.parts={}
	start=tick
	state="dead"
	if extralives<0 then
		gameoveranimation=cocreate(gameover)
		add(a2,gameoveranimation)
	else
		dethmsg=cocreate(deathmsg_anim)
		add(a2,dethmsg)
	end
	while btn()==0 do
		local pct=min((tick-start)/duration,1)
		if pct<=1 then
			cp=bwp[ceil((1-pct)*#bwp)]
		else
			cp=dp
		end
--		cp=pct~=1 and bwp[ceil((1-pct)*#bwp)] or dp
		yield()
	end
	cp=dp
	if extralives<0 then
		del(a2,gameoveranimation)
		lvl=1
		extralives=mulligans
		state="title"
		title=cocreate(title_setup)
	else
		del(a2,dethmsg)
		state="setup"
		add(as,cocreate(spawn))
	end
end

function gameover()
	local wid=print("gameover",129,0)-129
	print("gameover",64-wid/2,64-10)
	local start=tick
	local c=0
	local tw=60--trackwidth
	local lvlstotal=20
	local tt=3 --ticks total
	local ts=tw/(#lvls/tt)--tick spacing
	local tb=64-tw/2 --ticks begin
	local yt=68 --tracks y pos
	local mascots={
		[0]=function(x,y) --roid
			circ(x,y,3,9)
			spr(2,x-4,y-4)
		end,
		[1]=function(x,y) --flower
			fillp(ˇ)
			circfill(x,y,4,11)
			fillp()
			spr(20,x-4,y-4)
		end,
		[2]=function(x,y) --bomb
			spr(18,x-4,y-4)
		end,
	}
	local tip=tips[ceil(rnd(#tips))]
	while true do
		c+=1
		print("gameover",64-wid/2,64-4)

		for i=0,tt do
			line(tb+i*ts,yt,tb+i*ts,yt+2,7)
			if i*tt>lvl then
				for i=0,15 do
					pal(i,1)
				end
			end
			if mascots[i]~=nil then
				mascots[i](64-tw/2+i*ts,yt+8)
			end
			pal(cp)
		end

		if c>30 then -- progress line
			local pct=min(1,(c-30)/10)
			line(tb,yt+1,tb+tw*pct*(lvl/#lvls),yt+1,8)
		end
		
		local ystart=yt+18
		for i=1,#tip do
			local msg=tip[i]
			if i==1 then msg="tip: "..msg end
			cprint(msg,64,ystart,6)
			ystart+=6
		end
		yield()
	end
	extralives=mulligans
end

function deathmsg_anim()
	local msg=rnd(dethmsgs)
	local ypos=62
	while true do
		cprint(msg,64,ypos,7)
		local mulls=extralives==1 and " mulligan" or " mulligans"
		cprint(""..extralives..mulls.." left this tau",64,ypos+12,6)
		for i=1,extralives+1 do
			if i==extralives+1 then
				if tick%20>10 then
					spr(22,i*6-6,10)
				end
			else
				spr(22,i*6-6,10)			
			end
		end
		yield()
	end
end
-->8
--utils

--euclidean dist
function dist(x1,y1,x2,y2)
	return sqrt((x1-x2) * (x1-x2)+(y1-y2)*(y1-y2))
end

--euclidean dist two points
function distt(t1,t2)
	return sqrt((t1.x-t2.x) * (t1.x-t2.x)+(t1.y-t2.y)*(t1.y-t2.y))
end

--circle/circle intersection
function touching(a,b)
	return distt(a,b)<a.r+b.r
end

--what array elements satisfy predicate function?
function filter(f,t)
	local r={}
	for _,v in ipairs(t) do
		if f(v) then add(r,v) end
	end
	return r
end

--do all array elements satisfy predicate function?
function allt(f,t)
	for _,v in ipairs(t) do
		if not f(v) then return false end
	end
	return true
end

function easeoutexpo(x)
	if x==1 then
		return 1
	else
		return 1-2^(-10*x)
	end
end

function easeinexpo(x)
	if x==0 then
		return 0
	else
		return 2^(10*x-10)
	end
end

function easeinoutquart(x)
	if x<.5 then
		return 8 * x * x * x * x
	end
		return 1 - ((-2 * x + 2)^4) / 2
end

--get random angle that is not within margin of given angle
function aim_away(ang,margin)
	local margin=margin or .25
	return rnd(1-margin)+ang+margin/2
end

--random range, from low to high not inclusive
function rndr(low,high)
	return low+rnd(high-low)
end

--https://www.lexaloffle.com/bbs/?tid=37554
function cprint(str,x,y,col)
 local strl=#str
 print(str,x-strl*2,y,col)
end

--https://www.lexaloffle.com/bbs/?pid=54963#p
function circle(x,y,r,c)
	local xo,yo,ba=0,r,3-2*r
	color(c)
	repeat
	  pset(x-xo,y-yo)pset(x-xo,y+yo)
	  pset(x+xo,y-yo)pset(x+xo,y+yo)
	  pset(x-yo,y-xo)pset(x-yo,y+xo)
	  pset(x+yo,y-xo)pset(x+yo,y+xo)
	  if (ba<0) ba+=6+4*xo else ba+=10+4*(xo-yo) yo-=1
	  xo+=1
	until xo>yo
end
 	
--https://www.lexaloffle.com/bbs/?pid=88836#p
function smallcaps(s)
  local t=""
  for i=1,#s do
    local c=ord(s,i)
    t..=chr(c>96 and c<123 and c-32 or c)
  end
  return t
end

-->8
--palletes
dp={ --default palette
0,0,0,0,
0,0,0,0,
0,0,0,0,
0,0,0,--padding
0,1,2,3,
4,5,6,7,
8,9,10,11,
12,13,14,15,
}
local bw1={
0,0,0,0,
0,0,0,0,
0,0,0,0,
0,0,0,--padding
0,0,0,6,
6,5,6,7,
6,6,7,7,
6,5,6,7,
}
local bw2={
0,0,0,0,
0,0,0,0,
0,0,0,0,
0,0,0,--padding
0,0,0,5,
5,0,5,6,
5,5,6,6,
5,0,5,6,
}
local bw3={
0,0,0,0,
0,0,0,0,
0,0,0,0,
0,0,0,--padding
0,0,0,0,
0,0,0,5,
0,0,5,5,
0,0,0,5,
}
local bw4={
0,0,0,0,
0,0,0,0,
0,0,0,0,
0,0,0,--padding
0,0,0,0,
0,0,0,0,
0,0,0,0,
0,0,0,0,
}
bwp={bw1,bw2,bw3,bw4}
-->8
--player animations

function blink_anim(x1,y1,x2,y2,duration)
	local grays={7,6,13,1}
	local totalduration=duration
	while duration>=0 do
		local pct=(totalduration-duration)/totalduration
		local idx=ceil(pct*#grays)
		p.x,p.y=x1,y1
		local lines=p:coords()
		for l in all(lines) do
			color(grays[idx])
			line(l.x1,l.y1,l.x2,l.y2)
		end
		duration-=1
		p.x,p.y=x2,y2
		yield()
	end
end

--ship lines,rocket point,prow
function p:coords()
	local m={x=p.x+cos(p.a)*2,y=p.y+sin(p.a)*2}
	local prow=.05
	local len=6
	local aft=len-2
	return
	-- ship lines
	{
		{x1=m.x,y1=m.y,x2=m.x-cos(p.a-prow)*len,y2=m.y-sin(p.a-prow)*len},
		{x1=m.x,y1=m.y,x2=m.x-cos(p.a+prow)*len,y2=m.y-sin(p.a+prow)*len},
		{x1=m.x-cos(p.a+prow)*len,y1=m.y-sin(p.a+prow)*len,x2=m.x-cos(p.a-prow)*len,y2=m.y-sin(p.a-prow)*len},
	},
	-- rocket point
	{x=m.x-cos(p.a)*(len+1),
	y=m.y-sin(p.a)*(len+1)},
	--prow
	{x=m.x,y=m.y}
end

--player death particles
function deathparticles(cause)
	local lines=p:coords()

	for l in all(lines) do
		l.dx,l.dy=cause.dx or p.dx,cause.dy or p.dy
		l.midx,l.midy=(l.x1+l.x2)/2,(l.y1+l.y2)/2
		l.dr=rnd(.05) l.r=atan2(l.x2-l.x1,l.y2-l.y1)
		local ang=atan2(l.midx-p.x,l.midy-p.y)
		l.dx+=cos(ang)*.25 l.dy+=sin(ang)*.25
	end

	local parts={}
	local s = 4 --dist spread
	local ds=.1 --speed spread
	for i=1,10 do
		local z = {x=p.x+rndr(-s,s),
													y=p.y+rndr(-s,s),
													dx=(cause.dx or p.dx)+rndr(-ds,ds),
													dy=(cause.dy or p.dy)+rndr(-ds,ds)}
		local ang=atan2(z.x-p.x,z.y-p.y)
		z.dx+=cos(ang)*0.1
		z.dy+=sin(ang)*0.1
		add(parts,z)
	end

	local i=10
	while not p.enabled do
		i-=1
		pal(dp)

--		if i>0 then
--			camera(rnd(4)-2,rnd(4)-2)
--		else
--			camera()
--		end
		color(7)
		for l in all(lines) do
			l.midx+=l.dx
			l.midy+=l.dy
			l.r+=l.dr
			line(l.midx-cos(l.r)*3,
								l.midy-sin(l.r)*3,
								l.midx+cos(l.r)*3,
								l.midy+sin(l.r)*3)
		end
		for z in all(parts) do
			z.x+=z.dx z.y+=z.dy
			pset(z.x,z.y)
		end
		pal(cp)
		yield()
	end
end

--player enter
function penter(x,y,duration)
	local start=tick
	local t=0
	local dur=duration/2
	sfx(18)
	while t<1 do
		t=(tick-start)/dur
		t=easeoutexpo(t)
		color(7)
		line(x,y,x+30*t,y)
		line(x,y,x-30*t,y)
		line(x,y,x,y+30*t)
		line(x,y,x,y-30*t)
		circfill(x,y,t*4)
		yield()
	end
	start=tick
	t=0
	while t<1 do
		t=(tick-start)/dur
		t=easeoutexpo(t)
		line(x,y,x+30*(1-t),y)
		line(x,y,x-30*(1-t),y)
		line(x,y,x,y+30*(1-t))
		line(x,y,x,y-30*(1-t))
		circfill(x,y,(1-t)*6,7)
		yield()
	end
end
-->8
--title screen
function title_setup()
	lz={}	zs={} hs={} rs={} fs={} b.enabled=false b.parts={}
	local a=rnd()
	add(lz,{a=a,x=64+cos(a)*63,y=64+sin(a)*63,speed=.005,parts={index=0}})
--	add(lz,{a=.5,x=64+cos(a)*63,y=64+sin(a)*63,speed=.0025,parts={index=0}})
	local a=aim_away(.25,.6)
	local d=rnd(64-24)+12
	add(hs,{x=64+cos(a)*d,y=64+sin(a)*d,
					r=3,dx=0,dy=0,t=.05,
					enabled=true,timer=0,
					frametick=0})
	for i=1,5 do
		local f={}
		f.tick=flr(rnd(100))
		f.max=12
		f.growgoal=120 --grow rate
		f.br=500 --bud rate
		local r={}
		local d=12+rnd(63-24)
		local a=rnd()
		r.x=64+cos(a)*d r.y=64+sin(a)*d r.r=9
		r.growcount=rnd(f.growgoal) r.hit=-100
		add(f,r)
		add(fs,f)
	end
	local z=flr(rnd(10))+3
	for i=1,z do
		local r={}
		local a=rnd()
		local d=rnd(64-24)+12
		r.x=64+cos(a)*d r.y=64+sin(a)*d
		local a2=rnd()
		local spd=rnd(1.25)+.5
		r.dx=cos(a2)*spd r.dy=sin(a2)*spd
		r.r=3+rnd(8-3) r.enabled=true
		r.hit=-10
		add(rs,r)
	end
	yield()
	local c=0
	local col1,col2=flr(rnd(16)),flr(rnd(16))
	local t,trate=1,.5
--	local fills={
--		0b1111000011110000.11,
--		0b0000111100001111.11
--	}
--	local fills={
--		0b0000000000000000.11,	
--		0b1111000000000000.11,
--		0b1111111100000000.11,
--		0b1111111111110000.11,
--		0b1111111111111111.11,
--	}
--	local fills={
--		0b1111111111111111.11,
--		0b1111111111110000.11,
--		0b1111111100000000.11,
--		0b1111000000000000.11,
--		0b0000000000000000.11,	
--	}
--	fills={
--[0]=0b0000111111111111.11,
--				0b1111111111110000.11,
--				0b1111111100001111.11,
--				0b1111000011111111.11,
--	}
	fills={
[0]=0b0000111111111111.11,
				0b1111000011111111.11,
				0b1111111100001111.11,
				0b1111111111110000.11,
	}
fills={
[0]=0b1111000000000000.11,
				0b0000111100000000.11,
				0b0000000011110000.11,
				0b0000000000001111.11,
	}

	fin=1
	local col1={14,8,2,1}
	local col2={1,2,8,14}
	local frate=.1
	local scany=0
	local dd=10--sleep input
	local haspressed=false
	while c<30 or not ((btn(❎) or btn(🅾️)) and haspressed) do
		c+=1
--give the bomb something to chase
		if rnd()>.9 then 
			p.a,p.x,p.y=rnd(),64+cos(p.a)*63,64+sin(p.a)*63
		end

--spritesheet coords
		local sc={x=69,y=8,x2=119,y2=47}
		sc.w,sc.h=sc.x2-sc.x+1,sc.y2-sc.y+1
--	screen coords
		local tc={x=39,y=18,w=sc.w,h=sc.h}
	
		pal(1,8)
		pal(7,0)
		sspr(sc.x,sc.y,sc.w,sc.h,tc.x,tc.y)

--convert scany into oscillator so lines goes up and down
--		local os=sin(scany/100)*sc.h

--scan line down the logotype
		pal()
		local colc
		for i=1,4 do
			local os=sin((scany+i)/100)*sc.h
			for x=1,sc.w do
				if os>.5 then colc=col2 else colc=col1 end
				if sget(sc.x+x,sc.y+os)==7 then				
					pset(tc.x+x,tc.y+os,colc[i])				
				end
			end
		end		
		scany+=1
--		if scany>100 then scany=0 end

		--difficulty choose
		if haspressed then
			dd-=1
			if btn()==0 then dd=-1 end
			if dd<0 then
				if btn(⬅️) or btn(⬇️) then 
					difficulty=mid(1,difficulty-1,3)
					dd=10
				end
				if btn(➡️) or btn(⬆️) then
					difficulty=mid(1,difficulty+1,3)
					dd=10
				end
			end
			
			local xoff,yoff,w,h=14,76,98,20
			for x=1,w do
				for y=1,h do
					if pget(x+xoff,y+yoff)~=0 then
						pset(x+xoff,y+yoff,1)
					end
				end
			end

			rect(xoff,yoff,xoff+w,yoff+h,1)
			cprint(diffmsg[difficulty],64,80,7)
			cprint(mulmsg[difficulty],64,88,7)
		end
		
		if btn()~=0 and not haspressed then
			haspressed=true
			c=10	
		end
		
		color(1)
		print(smallcaps("@").."c"..smallcaps("asey"),104,117)
		print("l"..smallcaps("abrack"),100,122)
		yield()
	end
	dset(2,difficulty)
	mulligans=difficulty==1 and 3 or 1
	extralives=mulligans
	state="wipe"
	wipe=cocreate(wipe_anim)
end
-->8
--misc animations
function rsplode(x,y,r,dx,dy)
	local c=0
	while c<10 do
		c+=1
		for i=i,12 do
			pset(x+rnd(r),y+rnd(r),4)
		end	
		x+=dx y+=dy
		yield()
	end
end

-- bullet hit animation
function b:splash(num)
	local num=num or 10
	for i=1,num do
		local ps={}
		ps.x,ps.y=self.x,self.y
		local d=rnd(4)
		local ang=rndr(-.2,.2)
		ps.dx=cos(b.a+.5+ang)*d
		ps.dy=sin(b.a+.5+ang)*d
		ps.t=rnd(6)
		add(self.parts,ps)
	end
end
__gfx__
00000000006dd60000000000000000000000000000c00c000020020000000000000000000000000066666666666666666666666600e000000000e00000000000
0000000006666660000000000e0000e00e0000e00c0cc0c00202202000200200002002000020020060000bb6600008866000000600ee00000000ee0000000000
0070070066dddd660000000000eeee0000eeee00c0c66c0c202222020200002002022020020220206000bbb6600888066000000600eeeeee0eeeee0000000000
00077000d6d88d6d0008000000e00e0000e88e000c6666c0022882200002200000200200002882006b0bb006608880066000000600e00ee0eee00e0000000000
00077000d6d88d6d0080800000e00e0000e88e000c6666c00228822000022000002002000028820060bb000668800006600000060ee00e0000e00eee00000000
0070070066dddd660008000000eeee0000eeee00c0c66c0c20222202020000200202202002022020666666666666666666666666eeeeee0000eeeee000000000
0000000006666660000000000e0000e00e0000e00c0cc0c0020220200020020000200200002002000000000000000000000000000000ee0000ee000000000000
00000000006dd60000000000000000000000000000c00c000020020000000000000000000000000000000000000000000000000000000e00000e000000000000
0f00000000f00000000f00000000f0000008000000eee00000700000f000000f0000000000000000000000000000000000000000100000000000000000000000
00f0000f000f00000000f00000000f00008080000e00eee0007000000f0000f00000000000000000000000000000000000000011710000000000000000000000
00fffff000ffff0f00ffff000fffff0008eee800e00000ee0777000000ffff000000000000000000011110000000000000000177710000000000000000000000
00f88f0000f88ff00ff88f0ff0f88f0080e8e080e000000e7707700000f22f000000000000000001177771000000000000001177710000000000000000000000
00f88f000ff88f00f0f88ff000f88f0f08eee800e00000ee7000700000f22f000000000000000117777777100000000000001777710000000000000000000000
0fffff00f0ffff0000ffff0000fffff0008080000e000ee00000000000ffff000000000000011777777777100000000000011777710000000011111000000000
f0000f000000f000000f000000f00000000800000ee0ee00000000000f0000f00000000000177777777771100000000000017717710000000177771000000000
000000f000000f000000f000000f000000000000000ee00000000000f000000f0000000000177777777771000000000000117717710000001777777100000000
00000000000000000101101000000000000000000000000000000000000000000000000000177777777771001111000000177717710000017777777100000000
05555500088888000011110000000000000000000000000000000000000000000000000000177771177710017771100001177117710000177777777100000000
55050550880808800110011000000000000000000000000000000000000000000000000000177111777710017777100001777117710000177777771000000000
55050550888888800110011000000000000000000000000000000000000000000000000000011017777100177777100001771017710001777777110000000000
55555550880008800011110000000000000000000000000000000000000000000000000000000017771000177777100017771017710017777771000000000000
05555500088888000101101000000000000000000000000000000000000000000000000000000177771001777777100017771117710017777710000000000000
05050500000000000000000000000000000000000000000000000000000000000000000000000177710001777777100177777777710177777100000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000001777710017771777100177777777710177771111111000000000
85800000555b000055500000ff000000000000000000000000000000000000000000000000001777100017771777101177777777711777711777771000000000
58500000b5b00000555000000f000000000000000000000000000000000000000000000000017777100177771777101777777777711777117777777100000000
858000005b50000055500000ff000000000000000000000000000000000000000000000000177771000177711777101777777777717771177777777100000000
000000000000000000000000f0000000000000000000000000000000000000000000000000177710000177101777117777111177717771177771777100000000
000000000000000000000000ff000000000000000000000000000000000000000000000001777710001777101777117771000177717710011111777100000000
00000000000000000000000000000000000000000000000000000000000000000000000001777100001777111777117771000177717710000177771100000000
00000000000000000000000000000000000000000000000000000000000000000000000017777100017777777777177710000177717711111777771000000000
00000000000000000000000000000000000000000000000000000000000000000000000017771000017777777777177710000177717771177777710000000000
00000000000000000000000000000000000000000000000000000000000000000000000177771000017777777777177100000177717777777777100000000000
00000000000000000000000000000000000000000000000000000000000000000000000177710000177777777777111100000177711777777771000000000000
00000000000000000000000000000000000000000000000000000000000000000000001777711110177777777777100000000177101777777710000000000000
00000000000000000000000000000000000000000000000000000000000000000000001777111771777777711777100000000011000177711100000000000000
00000000000000000000000000000000000000000000000000000000000000000000001777777771777711101777100000000000000011100000000000000000
00000000000000000000000000000000000000000000000000000000000000000000017777777771777100001777100000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000017777777717771000001777100000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000017777777717771000001777100000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000001777771177771000001777100000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000001771110177710000000111000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000001110000177710000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000001777100000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000001771100000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000001771000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000001710000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000066666666666666600000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000066666600000000000000066666600000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000666600000000000000000000000000066660000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000666000000000000000000000000000000000006660000000000000000000000000000000000000000000
00000000000000000000000000000000000000000666000000000000000000000000000000000000000006660000000000000000000000000000000000000000
00000000000000000000000000000000000000066000000000000000000000000000000000000000000000006600000000000000000000000000000000000000
00000000000000000000000000000000000006600000000000000000000000000000000000000000000000000066000000000000000000000000000000000000
00000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000
00000000000000000000000000000000066000000000000000000000000000000000000000000000000000000000006600000000000000000000000000000000
00000000000000000000000000000006600000000000000000000000000000000000000000000000000000000000000066000000000000000000000000000000
00000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000
00000000000000000000000000006600000000000000000000000000000000000000000000000000000000000000000000066000000000000000000000000000
00000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000
00000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000
00000000000000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000006600000000000000000000000
00000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000
00000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000
00000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000
00000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000
00000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000
00000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000
00000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000
00000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000
00000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000
00000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000
00000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000
00000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000
00000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000
00000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000
00000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000
00000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000
00000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000
00000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000
00000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000
00000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000
00000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000
00000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000
00000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000
00000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000
00000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000
00000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000
00000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000
00000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000
00006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000
00006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000
00006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600
00006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000
00006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000
00006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000
00000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000
00000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000
00000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000
00000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000
00000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000
00000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000
00000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000
00000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000
00000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000
00000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000
00000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000
00000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000
00000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000
00000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000
00000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000
00000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000
00000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000
00000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000
00000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000
00000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000
00000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000
00000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000
00000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000
00000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000
00000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000
00000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000
00000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000
00000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000
00000000000000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000006600000000000000000000000
00000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000
00000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000
00000000000000000000000000006600000000000000000000000000000000000000000000000000000000000000000000066000000000000000000000000000
00000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000
00000000000000000000000000000006600000000000000000000000000000000000000000000000000000000000000066000000000000000000000000000000
00000000000000000000000000000000066000000000000000000000000000000000000000000000000000000000006600000000000000000000000000000000
00000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000660000000000000000000000000000000000
00000000000000000000000000000000000006600000000000000000000000000000000000000000000000000066000000000000000000000000000000000000
00000000000000000000000000000000000000066000000000000000000000000000000000000000000000006600000000000000000000000000000000000000
00000000000000000000000000000000000000000666000000000000000000000000000000000000000006660000000000000000000000000000000000000000
00000000000000000000000000000000000000000000666000000000000000000000000000000000006660000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000666600000000000000000000000000066660000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000066666600000000000000066666600000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000066666666666666600000000000000000000000000000000000000000000000000000000

__sfx__
0005000005650096500e65013650176502165000000000001d6001e600216000000024600286002e6002f600000000000000000000001c6001d6001e6001f600000001f600206000000020600206000000021600
000400000725008250082500a2500c2500f250132501d250232502c250332503e2500020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
0006000a0b6200b6200b6200b6200a6200a6200b6200b6200b6200d6200d6000d6000d6000d6000d6000d60000000000000000000000000000000000000000000000000000000000000000000000000000000000
000e000702710027100471004710027100b7100b7100f70005700047002e7002e7000370003700037000370003700037000370003700037000370003700077000770007700077000770000700007000070000700
001000000a0500b0500c0500c0500c0500f0500f0500f050110501105013050130501605016050160501805018050180501b0501b0501b0501b05000000000000000000000000000000000000000000000000000
011000000c1500a1000a1000a1000c1500a100001000a1000c1500a1000a1000a1000c1503310000100001000c1000c150001001d1000c1501b1001d1001f1000c1500010000100001000c150001000010000100
000300002e3502e35016350113500f3500c3500a350163001330016300113000a30000300053000a3000730007300073000730007300073000c3000a300073000730000300003000030000300003000030000300
000400000a2100a2100a2200a2300a2400a2500c2000c2000f2000f2001120016200162001b2001d2002220024200292002e200332003a2003f20000200002000020000200002000020000200002000020000200
000500000e6600e6500e6400e6300e610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000c4500c4500c4500c45027450274502445024450274502745024450244500040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
000400001b5501f550225502b55024550295503055033550005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
000100003f5203f5203c5203a52037520375203752033520305202e520295202752024520245202252022520225201f5201d5201d5201d52018520185201652016520115200f5200f5200c5200a5200a52007520
000800000352000510075000750007500075000750007500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000316503165030650316503a70037700306502c6502d6502e650307003370033700276002c6502d6502c65030700276002d6502c650306503365000700007002a6502a650296500070024650226501f650
001400000c1200a12007120031200f1200c1200a120071200c1200a12007120031200f1200c1200a120071200c1200a12007120031200f1200c1200a120071200c1200a12007120031200f1200c1200a12007120
011400000a650006000060000600056500060000600006000a650006000060000600056500060000600006000a650006000060000600056500060000600006000a65005600036000060005650006000060000600
001400001145011450114501145011400114001345216452114001345016450164001145011450114501145000400274002740027400274000040000400004000040000400004000040000400004000040000400
011400000645014400114000000006450084500545000000064501440011400000000645008450054500000006450144001140000000064500845005450000000645014400114000000006450084500545000000
000800000f5501b550275503355000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
00020d123551033510305102e5102e5102b5102951027510225101b5101651013510115100f5100f5100f5100f5100f5100050000500005000050000500005000050000500005000050000500005000050000500
000200003f5203c5203c5203a5203552035520335202e5202b5202b52029520275202452022520225201f5201d5201b520185201652013520115200f5200f5200c5200c5200a5200a52007520055200352003520
000200000576022760297601d76007760077600070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010600003a4513745135451334511d4510f4510740100401074010040100401004010040100401004010040100401004010040100401004010040100401004010040100401004010040100401004010040100401
0108000005050070400a030130201f010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000005450074400a630136201f410004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
000200000571022710297101d71007710077100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0e0f4344
00 0e0f4344
00 0e110f44

