pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- zaag
-- casey labrack

--todo:
-- the hit palette bug
-- boss restart palette bug?
-- sound for boss charging attack

--😐:
-- unique death animations
-- custom font? for tau
-- music?
-- toggle enable flip? 'enable ship flip'
-- option: skip tau 0
-- intro: detailed ship zooming through taus (tunnel)
-- you have only your blaster--and spares

version=53
_g=_ENV
dmg={ 
	{roid=2,flower=2,bomb=120,boss=4},--easy
	{roid=1.5,flower=1.5,bomb=90,boss=3},--normal
	{roid=1,flower=1,bomb=60,boss=2},--hard
}
laserspeeds={.0025,.002,.0015}
--laserspeeds={.005,.004,.003}
--players, lasers, safe zones, animations (coroutines), animations in draw phase, flowers, roids, bullets
ps,lz,zs,as,a2,fs,rs,bs={},{},{},{},{},{},{},{}
inner,outer_r={x=64,y=64,r=6,enabled=true},63
lvl,mulligans=1,1
extralives=mulligans
mulldiff={2,1,0} --how many mulligans for each difficulty
mulmsg={ --titlescreen mulligan description
"(2 spares, 2x pwr)",
"(1 spare, 1.5x pwr)",
"(0 spares, 1x pwr)",
}
diffmsg={--titlescreen difficulty description
"difficulty: practice",
"difficulty: challenge",
"difficulty: prestige",
}
tick,state=0,"title"
cp=dp--current pallete
sleep,shake=0,0
pthrusting=false --was anybody making the thrust noise last frame?
seconds,minutes=0,0

--properties shared by p1 and p2
charge,fullcharge,hopfail,hopfailtick=460,460,false,0
gun=0 gunfull=240 gunfail=false gunfailtick=0

--difficulty:1 easy,2 med,3 hard

--[[coroutines:
  wipe
  blink
  title
  dethmsg
  dethparts
  gamewon]]

--log=""

--cartdata slots
--0: action button swap
--1: death gifs
--2: last difficulty
--3: is noob
--4: screenshake toggle (0 is on, 1 is off)

dethmsgs=split(
[[zigged when i shoulda zaaged
sun was in my eyes
mistakes were made
testing ejector seat
tax write-off
had an oopsie-doopsie
no one is perfect
lag!
😐]],"\n")

tips={
	{"remember to take","15 minute breaks!"},
	{"zaag is a fun game"},
	{"very close range shots","= very fast rate of fire"},
--	{"quick flip (⬇️) is","faster than doing a 180"},
	{"pause screen has some","additional options"},
	{"real winners","say no to drugs"},
	{"blaster has warm up,","tele is charged at start"},
	{"if it's weird-looking,","shoot it"},
	{"a zoid tail shows","zoid speed and direction"},
	{"in two-pilot missions,","please try to limit","friendly fire incidents"},
	{"don't panic"},
}

function _init()
	poke(0x5f34,0x2)--inverse fill
	cartdata("caseylabrack_zaag")
	local swapped=dget(0)==1
	fire_btn  = (not swapped) and ❎ or 🅾️ 
	tele_btn = (not swapped) and 🅾️ or ❎
	deathgifs=dget(1)==1
	difficulty=dget(2)
	screenshake=dget(4)==0
	difficulty=difficulty==0 and 1 or difficulty
	initplayers()

	-- bullets init	
	for i=1,2 do
		add(bs,
		setmetatable({
			x=0,y=0,a=0,dx=0,dy=0,enabled=false,
			r=2,speed=2.5,parts={},id=i-1,
			splash=function(_ENV)
				for i=1,10 do
					local ps={}
					ps.x,ps.y=x,y
					local d,ang=rnd(4),rndr(-.2,.2)
					ps.dx,ps.dy,ps.t=cos(a+.5+ang)*d,sin(a+.5+ang)*d,rnd(12)
					add(parts,ps)
				end
				enabled=false 
				sfx(20,-2)
			end,
			
			doparticles=function(_ENV)
				for bp in all(parts) do
					bp.t-=1
					bp.x+=bp.dx or 0
					bp.y+=bp.dy or 0
					if bp.t<0 then
						del(parts,bp)
					end
				end
			end,
			
			render=function(_ENV)
--				if not enabled then return end
				if enabled then
					line(x,y,x-dx,y-dy,12)
				end
				for p in all(parts) do
					pset(p.x,p.y,12)
				end
			end,
		},{__index=_ENV}))
	end
	
	
--	_update60=_mainupdate
--	_draw=_maindraw
--	tick=0
--	title=cocreate(title_setup)
	_update60=nil
	_draw=introdraw
	
--	menuitem(1, "swap ❎/🅾️ btns", btns_toggle)
--	menuitem(2, "save screenshot", function () extcmd("screen") end)
--	menuitem(2, "death gifs: " ..(deathgifs and "on" or "off"), dethgiftoggle)
--	menuitem(4, "screenshake: "..(screenshake and "on" or "off"), screenshake_toggle)
end

--function btns_toggle()
--	if fire_btn==❎ then	
--		fire_btn=🅾️ tele_btn=❎
--		dset(0,1)
--	else	
--		fire_btn=❎ tele_btn=🅾️
--		dset(0,0)
--	end 
--end

--function dethgiftoggle()
--	deathgifs=not deathgifs
--	dset(1,(deathgifs and 1 or 0))
--	menuitem(2, "death gifs: " ..(deathgifs and "on" or "off"), dethgiftoggle)
--	return true
--end

--function screenshake_toggle()
--	screenshake=not screenshake
--	menuitem(4, screenshake==true and "screenshake: on" or "screenshake: off",screenshake_toggle)
--	dset(4,screenshake==true and 0 or 1)
--	return true
--end

function _mainupdate()
tick+=1

if tick%60==0 then
	seconds+=1
	if seconds%60==0 then
		seconds=0
		minutes+=1
	end
end

-- do animations
for a in all(as) do
	if costatus(a)!="dead" then assert(coresume(a))
	else del(as,a) end
end

if state=="setup" or state=="wipe" or state=="win" then
	return
end

--pauses most game logic for a number of frames
if sleep>0 then
	sleep-=1
	return
end

charge+=1
gun=min(gun+1,gunfull)
boss:update()

-- play rocket noise (only once) if either is rocketing
local thrust=ps[1].thrusting or ps[2].thrusting
if pthrusting then
	if not thrust then sfx(2,-2) end
else	
	if thrust then sfx(2) end
end
pthrusting=thrust

--flowers
for f in all(fs) do
	f.tick+=1
	for l in all(f) do --each leaf
	for p in all(ps) do
		if p.enabled and touching(p,l) then died(p,l) end
	end
		l.growcount+=1
		if l.growcount>f.growgoal and l.r<12 then --grow
			if not touching(l,inner) then
				l.r+=1
				l.growcount=0
			end
		end
	end
	if f.tick%f.br==0 and #f<f.max then --bud
		local couldbuds=filter(function(x) return x.r>=12 end, f)
		if #couldbuds>0 then
			local k,ang,colliding,i,l={},0,true,0,{}
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
	l.x,l.y=64+cos(l.a)*63,64+sin(l.a)*63
	
	if #zs>0 and zs[1].state~="moving" then
		local s=zs[1] --safezone
		local atosafe=atan2(s.x-64,s.y-64)
		local diff=sad(atosafe,l.a)
		
		-- hit safezone instead
		if abs(diff)<30 then 
			circ(s.x,s.y,s.r,10)
			circfill(s.x,s.y,s.r,10)			

			local inzone=true
			local dx,dy=cos(l.a),sin(l.a)
			
			while inzone do
				l.x-=dx l.y-=dy
				inzone=pget(l.x,l.y)==10
			end						
		end
	end
	
	--do laser particles
	for z in all(l.parts) do
		z.x+=z.dx z.y+=z.dy
		z.dx*=.95 z.dy*=.95
		if tick-z.tick>10 then
			del(l.parts,z)
		end
	end

	--create laser particles	
	local a=l.a+.5+rndr(-.25,.25)
	add(l.parts,{
		x=l.x,y=l.y,
		dx=cos(a)*rnd(),dy=sin(a)*rnd(),
		tick=tick
	})
end

-- safe zones
for z in all(zs) do
	if z.state=="idle" then
		if touching(ps[1],z) or (ps[2].playing and ps[2].enabled and touching(ps[2],z)) then
			z.state="shrinking"
		end
	elseif z.state=="shrinking" then
		z.t-=.125
		if z.t<2 then 
			z.state,z.start,z.dist,z.mstart="moving",z.a,rnd(),tick
		end
	elseif z.state=="moving" then
		local pct=min(1,(tick-z.mstart)/z.mdur)
		if pct<1 then
			pct=easeinoutquart(pct)
			z.a=z.start+z.dist*pct
			z.x,z.y=64+cos(z.a)*63,64+sin(z.a)*63
		else
			z.t,z.state=32,"idle"
--			z.state="idle"
		end
	end
end

--homing bomb move
h:update()

for p in all(ps) do

	p:update()
	
	if not p.playing then break end

	local ang=atan2(p.x-64,p.y-64)
	
-- player vs outside wall
	if dist(p.x,p.y,64,64)>63 then
		p.x,p.y=64+cos(ang)*63,64+sin(ang)*63
	end
	
-- player vs inside wall
	if touching(inner,p) then
		p.x,p.y=64+cos(ang)*8,64+sin(ang)*8
	end
	
	if p.enabled then
		-- player vs. obstacles
		for v in all(rs) do
			if (touching(p,v)) died(p,v)
		end
	
		--player vs. homing bombs
		if h.enabled and touching(p,h) then 
			died(p,h)
		end
		
		--player vs. boss
		if boss.enabled and touching(p,boss.floor) then
				died(p,boss)
		end
		
		--laser/player collision
		local d=dist(p.x,p.y,64,64)
		local vulnerable=true
		for z in all(zs) do
			if z.state~="moving" and touching(p,z) then vulnerable=false break end
		end
		if vulnerable then
			for l in all(lz) do
				if touching(p,{x=64+cos(l.a)*d,y=64+sin(l.a)*d,r=0}) then
					died(p,l)
				end
			end
		end
	end
end

--zoids bouncing around
for v in all(rs) do
	if not v.enabled then goto continue end
	v.x=v.x+v.dx
	v.y=v.y+v.dy
	if dist(v.x,v.y,64,64)>63 then
		local a=atan2(v.x-64,v.y-64)
		local x=64+cos(a)*63
		local y=64+sin(a)*63
		v.x=x v.y=y
		deflect(v,a)
	end
	if dist(v.x,v.y,64,64)<4+v.r and lvl~=12 then
--	if dist(v.x,v.y,64,64)<4+v.r and inner.enabled then
		local a=atan2(v.x-64,v.y-64)
		local x=64+cos(a)*(4+v.r)
		local y=64+sin(a)*(4+v.r)
		v.x=x v.y=y
		deflect(v,a)
	end
	::continue::
end

--bullet
for b in all(bs) do

	b:doparticles()

	if b.enabled then
		local x1,y1=b.x,b.y
		for i=1,5 do -- bullet collision
			b.x,b.y=x1+b.dx*i/5,y1+b.dy*i/5
			add(b.parts,
			{x=b.x,y=b.y,t=rnd(3)})
			for f in all(fs) do --flowers
				for l in all(f) do --leaves
					if touching(b,l) then
						b:splash()
	--					sfx(24)
--						sfx(21)
						l.r-=dmg[difficulty].flower
						l.growcount=0
						l.hit=tick
						if l.r<3 then
							shake+=5
							sleep+=4
							del(f,l)
							sfx(43)
							if #f==0 then del(fs,f) end
						else
							sfx(42)
						end
						goto donebullet
					end
				end
			end
			for v in all(rs) do --roids
				if touching(b,v) then
					b:splash()
--					sfx(21)					
					local oldr=v.r
					v.r-=dmg[difficulty].roid
					v.hit=tick
--					shake+=5
					if v.r<3 then	
						shake+=5
						local z=cocreate(rsplode)
						coresume(z,v.x,v.y,oldr,v.dx,v.dy)
						add(a2,z)
						del(rs,v) 
						sfx(43)
						sleep+=4
					else
						sfx(42)
					end
					goto donebullet
				end
			end
			for p in all(ps) do
				if b.id~=p.id and p.enabled and touching(b,p) then
					p.dx+=b.dx/4
					p.dy+=b.dy/4
					b:splash()
					goto donebullet
				end
			end
			if h.enabled and touching(h,b) then
				sfx(42)
				b:splash()
				h.stunned=true
				h.timer=dmg[difficulty].bomb
				h.dx+=b.dx/4	h.dy+=b.dy/4
				goto donebullet
			end
			if boss.enabled and touching(boss,b) then
				boss.hp-=dmg[difficulty].boss
				boss.lasthit=tick
				b:splash()
				sfx(42)
				goto donebullet
			end			
			if touching(inner,b) or distt(inner,b)>63 then
				b:splash()
				goto donebullet
			end
		end
	end
	::donebullet::
end

--level win
if ps[1].enabled or ps[2].enabled then
	if #rs==0 and #fs==0 and boss.enabled==false and state=="running" then
		state="wiping"
		extralives=mulligans
		ps[1].thrusting,ps[2].thrusting=false,false
		pthrusting=false
		sleep=0
		sfx(2,-2)
		if lvl==2 then dset(3,1) end
		lvl+=1
		wipe=cocreate(wipe_anim)
		state="wipe"
	end
end

-- game win
if boss.enabled and state~="win" and boss.hp<0 then
	sfx(40)
	state="win"
	local a=cocreate(gamewin_anim)
	coresume(a)
	add(a2,a)
end

end


function died(player,cause)
	if state~="running" then return end
--	sfx(2,-2)
	sfx(13)
	shake+=20
	if player.enabled then
		player.enabled=false
		player.thrusting=false
		player:death(cause)
	end
	
	if not ps[1].enabled and not ps[2].enabled then
--		log="lose"
		extralives-=1
		state="death"
		local a=cocreate(death)
		coresume(a,15)
		add(as,a)
	end
end

function _maindraw()
cls()

camera()
if sleep<=0 then --hitstop, then shake
	if shake>0 then
		if screenshake then
			local a=rnd()
			local mag=(shake/8)^2
			camera(cos(a)*mag,sin(a)*mag)
		end
		shake-=1
	end
end

pal(cp)

--tau zero instructions
if lvl==0 and (state=="running" or state=="setup") then
	cprint("blast the zoids.",64,24,1)
	cprint("cleanse the tau.",64,36,1)
	local x,y,lh=40,78,8
	y+=lh
	color(btn(❎) and 12 or 1)
	print("❎ (x): "..(fire_btn==❎ and "shoot" or "tele"),x,y)
	y+=lh
	color(btn(🅾️) and 12 or 1)
	print("🅾️ (z): "..(tele_btn==🅾️ and "tele" or "shoot"),x,y)
end

--safe zone
for z in all(zs) do
	if z.state=="idle" or z.state=="shrinking" then
	fillp(32125)
	circfill(z.x,z.y,z.r,0x01)
	fillp()
	circfill(z.x,z.y,z.r-z.t,0)
	circ(z.x,z.y,z.r,1)
	end
end

--clip game artwork (safezones) to circle
circfill(64,64,outer_r,0 | 0x1800)

--do animations
for z in all(a2) do
	if costatus(z)!="dead" then assert(coresume(z))
	else del(a2,z) end
end

--safezone bot
for z in all(zs) do
	spr(5,z.x-4,z.y-4)
end

pal()
--if outer.enabled then
	circ(64,64,outer_r,6)
--	circle(outer.x,outer.y,outer.r,6)
--end
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

--boss flower
if boss.enabled then
	fillp(ˇ)
	circfill(boss.floor.x,boss.floor.y,boss.floor.r*(1-boss.detht),11)
	fillp()
end

--emitter
if state~="dead" and inner.enabled then
	circfill(64,64,inner.r,0)
	circ(64,64,inner.r,6)
end

--homing bombs
h:render()

--player
for p in all(ps) do
	p:render()
	pal(dp)
	p:renderdeath()
	pal(cp)
end

-- roids
for v in all(rs) do
	circ(v.x,v.y,v.r,tick-v.hit>4 and 9 or 7)
	spr(2,v.x-4,v.y-4)
	local a=atan2(v.dx,v.dy)-.5
	local x,y,m=v.x+cos(a)*v.r,
													v.y+sin(a)*v.r,
													dist(0,0,v.dx,v.dy)*3
	line(x,y,x+cos(a)*m,y+sin(a)*m)
end

--boss
boss:render()

--bullet
for b in all(bs) do
	b:render()
end

if wipe and costatus(wipe)~="dead" then coresume(wipe) end
--if dethparts and costatus(dethparts)~="dead" then coresume(dethparts) end
if blink and costatus(blink)~="dead" then coresume(blink) end

pal()

if state=="running" then
	--gun countdown
--	local p=ps[2].playing and ps[2].enabled and ps[2] or ps[1]
	local x,y,x2,y2=97,0,127,8
	local pct=min(gun/gunfull,1)
--	local pct=min(p.gun/p.gunfull,1)
	local f=gun<gunfull and 1 or 12
	log=gunfail
	if gunfail then
 	f=8
		gunfail=false
	end
	clip(x,y,(x2-x)*pct+1,y2+1)
	rect(x,y,x2,y2,f)
	clip()
	print("blaster",x+2,y+2,f)
	
 --hop countdown
	local f=charge<fullcharge and 3 or 11
	if hopfail then
		f=8
		hopfail=false
	end
 local pct=min(charge/fullcharge,1)
--	local x,x2,y,y2=107,127,10,18
	local x,x2,y,y2=109,127,10,18
	clip(x,y,(x2-x)*pct+1,10)
	rect(x,y,x2,y2,f)
	clip()
	print("tele",x+2,y+2,f)
end

-- boss ui
if boss.enabled then
	local c=tick-boss.lasthit<10 and tick%4<2
	line(0,126,32*(boss.hp/360),126, c and 7 or 14)
	color(14)
	for i=0,3 do
		pset(32*i/3,127)
	end
	print("zoidhive",0,120)
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

--if state=="death" and outer.enabled then
if state=="death" then
	circle(64,64,outer_r,6)
end

if title and costatus(title)~="dead" then coresume(title) end

--print(log,0,120,7)

end

-->8
--levels
lvls={
--	[0]={flowers=1},
--	[0]={roids=1,lasers=1},
--	{roids=4,lasers=1},--1
--	{roids=6,lasers=1,safezone=true},--2
--	{roids=4,lasers=1,flowers=2},--3
--	{roids=5,lasers=1,flowers=3},--4
--	{roids=6,lasers=1,flowers=4,safezone=true},--5
--	{roids=4,bomb=true},--6
--	{roids=4,flowers=3,bomb=true},--7
--	{roids=3,flowers=2,bomb=true,lasers=1,safezone=true},--8
--	{roids=6,lasers=2},--9
--	{roids=8,lasers=2,safezone=true},--10
--	{roids=6,lasers=2,flowers=2,safezone=true},--11
	{boss=1,lasers=3,safezone=true} --12
}

function wipe_anim()
	yield()
	sfx(32)
--	outer.enabled=false	
	local start=tick
	while tick-start<60 do
		if tick-start==30 then ps[1].enabled=false end
		local pct=easeinexpo((tick-start)/60)
--		local pct=(tick-start)/30
--		pct=easeinexpo(pct)
		local r=inner.r+(63-inner.r)*pct
		circfill(64,64,r,0)
		circ(64,64,r,6)
		outer_r=63+pct*50
		yield()
	end
	circfill(64,64,63,0)
	circ(64,64,63,6)
	clearlevel()
	outer_r=63
	add(as,cocreate(spawn))
end

function spawn()
	tick=0
	state,i,c="setup",20,22
	for p in all(ps) do
		p:spawn()
	end
	charge=fullcharge
	gun=0
	gunfailtick=0
	sleep,shake=0,0

	while c>0 do c-=1 yield() end
	inner.enabled=true
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
				local to_p=atan2(ps[1].x-r.x,ps[1].y-r.y)
				local a2=aim_away(to_p,.25)
				local spd=(rnd(1.25)+.5)/2
				r.dx=cos(a2)*spd r.dy=sin(a2)*spd
				r.r=3+rnd(8-3) r.enabled=true
				r.hit=-10
				add(rs,r)
				sfx(6)
				if #rs==num then break end
			end
			if unit=="safezone" then
				local a=rnd()
				add(zs,{a=a,x=64+cos(a)*63,y=64+sin(a)*63,r=32,
											state="moving",mstart=tick,mdur=360,dist=rnd(),start=a})
				sfx(10)
				break
			end
			if unit=="lasers" then
				local a=(1/num)*#lz+.1
				add(lz,{a=a,x=64+cos(a)*63,y=64+sin(a)*63,speed=laserspeeds[num],parts={index=0}})
				sfx(7)
				if #lz==num then break end
			end
			if unit=="bomb" then
				h:spawn()
				sfx(9)
				break
			end
			if unit=="flowers" then
				local f={}
				f.tick,f.max=flr(rnd(10)),4
				f.growgoal=60 --grow rate
				f.br=(150+flr(rnd(100)))*2 --bud rate
				local r,d={},12+rnd(63-24)
				local a=aim_away(.25,.25)
				r.x,r.y,r.r=64+cos(a)*d,64+sin(a)*d,9
				r.growcount=-rnd(60) r.hit=-100
				add(f,r)
				add(fs,f)
				sfx(8)
				if #fs==num then break end
			end
			if unit=="boss" then
				boss:spawn()
--				sfx(38)
				music(15)
				break
			end
			c=i
			::continue::
			yield()
		end
	end
	c=i
	while c>0 do c-=1 yield() end
	state="running"
	extcmd("rec")
end

function death(delay)
	yield()
	while delay>0 do
		delay-=1
		yield()
	end
	local start=tick
	while tick-start<60 do
		local pct=(tick-start)/60
		cp=bwp[ceil(pct*#bwp)]
		yield()
	end
	clearlevel()
	start=tick
	state="dead"
	if deathgifs then extcmd("video") end
	if extralives<0 then
		gameoveranimation=cocreate(gameover)
		add(a2,gameoveranimation)
	else
		dethmsg=cocreate(deathmsg_anim)
		add(a2,dethmsg)
	end
	while btn()==0 do
		local pct=min((tick-start)/60,1)
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
	local start=tick
	local c=0
	local tw=60--trackwidth
	local tt=5 --ticks total
	local ts=tw/4--tick spacing
	local tb=64-tw/2 --ticks begin
	local yt=68 --tracks y pos
	local mascots={
		[1]=function(x,y) --roid
			circ(x,y,3,9)
			spr(2,x-4,y-4)
		end,
		[2]=function(x,y) --flower
			fillp(ˇ)
			circfill(x,y,4,11)
			fillp()
			spr(20,x-4,y-4)
		end,
		[3]=function(x,y) --bomb
			spr(21,x-4,y-4)
		end,
		[4]=function(x,y) --double
			line(x-3,y-3,x+3,y+3,8)
			circfill(x,y,1,0)
			circ(x,y,1,6)
		end,
		[5]=function(x,y) --boss
			circ(x,y,4,14)
			circ(x,y,1,8)
		end
	}
	local tip=rnd(tips)
	while true do
		c+=1

		sspr(21,40,106,16,12,46)--gameover text

		local xl=tb
		for i=1,5 do --draw 5 ticks
			line(xl,yt,xl,yt+2,7)
			if lvl < (i-1)*3 then
				for j=0,15 do
					pal(j,1)
				end
			end
			mascots[i](xl,yt+8)
			pal(cp)
			xl+=ts
		end

		if c>60 then -- progress line
			local pct=min(1,(c-60)/20)
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
		cprint("pilot notes:", 64, ypos-8,7)
		cprint("\""..smallcaps(msg).."\"",64,ypos,6)
		local mulls=extralives==1 and " spare" or " spares"
--		local mulls=extralives==1 and " mulligan" or " mulligans"
		cprint(""..extralives..mulls,64,ypos+24,13)
		cprint("left this tau",64,ypos+32,13)
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

function gamewin_anim()
--stop timer, convert to formatted string
	local final_time=""..minutes..":"..(seconds<10 and "0"..seconds or seconds)

	local i=90	
	for v in all(rs) do --roids
		local z=cocreate(rsplode)
		coresume(z,v.x,v.y,v.r,v.dx,v.dy)
		add(a2,z)
		del(rs,v) 
	end
	
	for b in all(boss.bulges) do
		local z=cocreate(rsplode)
		coresume(z,b.x,b.y,b.r,0,0)
		add(a2,z)
		del(boss.bulges,b)
	end
	
	while i>0 do -- delay for boss outro
		i-=1

		local pct=1-i/180	
		boss.detht=pct	
		local dx,dy=64-boss.steadyx,64-boss.steadyy
		dx*=.1
		dy*=.1
		
		boss.steadyx+=dx
		boss.steadyy+=dy
		
		boss.x,boss.y=boss.steadyx+rnd()*3*(1-pct),boss.steadyy+rnd()*3*(1-pct)
		
		yield()
	end
	i=120
	while i>0 do --fade out
		local pct=1-i/120
		cp=bwp[ceil(pct*#bwp)]
		i-=1
		yield()
	end
	clearlevel()
	inner.enabled=false
	ps[1].enabled,ps[2].enabled=false,false
	
--	local msg=rnd({"2 ez","gottem","booyah."})
	local msg=split"gottem,booyah,2 ez."
	i,cp=180,dp
	sfx(39)
	while i>0 or (btn()==0 or btn()>3) do --fade back in, then exit with anykey
		local pct=i/180
--		cp=bwp[ceil(pct*#bwp)]
		i-=1

--		local ypos=62
		
		cprint("every tau immaculate!", 64,30,7)
		cprint("pilot notes:",64,54,7)
		cprint("\""..smallcaps(msg[difficulty]).."\"",64,62,6)

		cprint("time: "..final_time,64,84,13)
		cprint(diffmsg[difficulty],64,90,13)

		yield()
	end	
	ps[1].enabled,ps[2].enabled=false,false
	state="title"
	title=cocreate(title_setup)
end

function clearlevel()		
		lz,zs,h.enabled,rs,fs={},{},false,{},{}
		for b in all(bs) do
			b.enabled=false b.parts={}
		end 
		boss.enabled=false		
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

function deflect(v,a)
	local inc=atan2(v.dx,v.dy)+.5 --incidence
	local def=a+a-inc
	local mag=dist(0,0,v.dx,v.dy)
	v.dx,v.dy=cos(def)*mag,sin(def)*mag
end

--signed angle difference
--https://math.stackexchange.com/posts/1649850/revisions
function sad (a1,a2)
	a1,a2=a1*360,a2*360
	return (a2 - a1 + 540) % 360 - 180
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

--easings.net
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
--misc

--homing bomb
h=setmetatable({
			r=3,dx=0,dy=0,t=.02,
			enabled=false,timer=0,
			frametick=0,
			spawn=function(_ENV)
				local a,d=aim_away(.25,.6),rnd(64-24)+12
				x,y,dx,dy,enabled,
				timer,frametick,stunnned=
				64+cos(a)*d,64+sin(a)*d,0,0,
				true,0,0,false
			end,
			
			update=function(_ENV)
				if enabled then
					if stunned then
						timer-=1
						if timer<0 then stunned=false end
					else
						local target=closestplayer(h)
						local a=atan2(target.x-x+rnd(4)-2,target.y-y+rnd(4)-2)
						dx+=cos(a)*t dy+=sin(a)*t
						frametick+=1
					end
					dx*=.97 dy*=.97
					x+=dx	y+=dy
					local a2=atan2(x-64,y-64)
					if dist(x,y,64,64)<8 then
						x,y=64+cos(a2)*8,64+sin(a2)*8
					end
					if dist(x,y,64,64)>63 then
						x,y=64+cos(a2)*63,64+sin(a2)*63
					end
				end
			end,
			
			render=function(_ENV)
				if enabled then
					palt(10,true)
					palt(0,false)
					local _x,_y=0,0
					if stunned then
						spr(23,x-4,y-4)
						_x,_y=rnd(),rnd()
					else
						spr((flr(frametick%16)/4)+16,x-4,y-4)
						_x=dx<0 and 1 or 0
						_y=dy<0 and 1 or 0
--						pset(x-(dx<0 and 1 or 0),y-(dy<0 and 1 or 0),8)
					end
					pset(x-_x,y-_y,8)
					palt()
				end
			end,
		},{__index=_ENV})


--palettes
dp={ --default
[0]=0,1,2,3,
4,5,6,7,
8,9,10,11,
12,13,14,15,
}
bwp={ --fade to black
	{
	[0]=0,0,0,6,
	6,5,6,7,
	6,6,7,7,
	6,5,6,7,
	},
	{
	[0]=0,0,0,5,
	5,0,5,6,
	5,5,6,6,
	5,0,5,6,
	},
	{
	[0]=0,0,0,0,
	0,0,0,5,
	0,0,5,5,
	0,0,0,5,
	},
	{
	[0]=0,0,0,0,
	0,0,0,0,
	0,0,0,0,
	0,0,0,0,
	}
}

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
-->8
--player

function initplayers()
	for i=1,2 do
		add(ps,
			setmetatable({
			playing=i==1,id=i-1,--plyrs 0 and 1
			pcolor=i==1 and 7 or 6,
			x=80,y=30,dx=0,dy=0,dr=0,
			a=.75,t=.1,rt=.00375,r=2,
			hop=25,
			enabled=false,thrusting=false,
--			gun=0,gunfull=120,gunfail=false,gunfailtick=0,
--			flipready=10,fliplast=0,
			deathlines={},deathpnts={},
			spawnticks=0,
			
			update=function(_ENV)
				if not enabled then return end
--				gun=min(gun+1,gunfull)
				if btn(➡️,id) then 
--					a-=rt
					dr-=rt 
				end
				if btn(⬅️,id) then 
--					a+=rt 
					dr+=rt
				end
--				if btn(⬇️,id) then
--					if tick-fliplast>flipready then
--					 a+=.5
--					 fliplast=tick
--				 end
--				end
				if btn(⬆️,id) then
					dx+=cos(a)*t
					dy+=sin(a)*t
					if not thrusting then
						thrusting=true
--						sfx(2)
					end
				else
--					sfx(2,-2)
					thrusting=false
				end
				if btn(tele_btn,id) then
--				if btn(⬆️,id) then
				 if _g.charge>_g.fullcharge then
						local lines=coords(_ENV)
						x+=cos(a)*hop
						y+=sin(a)*hop
						thrusting=false
						_g.blink=cocreate(blink_anim)
						coresume(_g.blink,lines)
						_g.charge=0
--						if ps[2].playing==false then _g.sleep=8 end
						sfx(22)
					else
						if tick-_g.hopfailtick>4 then
							_g.hopfail=true
							sfx(12)
							_g.hopfailtick=tick
						end
					end
				end
				if btn(fire_btn,id) and not bs[id+1].enabled then
					if gun==gunfull then
						local b=bs[id+1]
						b.enabled=true
						b.x,b.y,b.a=x,y,a
						b.dx,b.dy=cos(b.a)*b.speed,sin(b.a)*b.speed
						sfx(44)
--						_g.shake+=2
--						sfx(25)
					else
						if tick-gunfailtick>4 then
							_g.gunfail=true
							sfx(12)
							_g.gunfailtick=tick
						end
					end
				end
				x+=dx
				y+=dy
				a+=dr
				dx*=.92 --apply friction
				dy*=.92
				dr*=.65
			end,
			
			render=function(_ENV)
				if not enabled then return end
				
				if spawnticks<8 then
					local lines,fire,prow=coords(_ENV)
					if thrusting then
						circfill(fire.x,fire.y,1,rndr(8,11))
					end
					for l in all(lines) do
						line(l.x1,l.y1,l.x2,l.y2,pcolor)
					end
				end
				
				if spawnticks==8 and id==0 then 
						sfx(18)--player spawn noise
				end
				
				if spawnticks>0 then
					spawnticks-=1
					color(pcolor)
					local t=0
					if spawnticks>8 then --expand
						t=1-(spawnticks-8)/8
					else --contract
						t=spawnticks/8
					end
					t=easeoutexpo(t)
					line(x,y,x+30*t,y)
					line(x,y,x-30*t,y)
					line(x,y,x,y+30*t)
					line(x,y,x,y-30*t)
					circfill(x,y,t*4)
				end
--				circ(x,y,r,10)
			end,
			
			coords=function(_ENV)
				local m={x=x+cos(a)*2,y=y+sin(a)*2}
				local prow=.05
				local len=6
				local aft=len-2
				return
				-- ship lines
				{
					{x1=m.x,y1=m.y,x2=m.x-cos(a-prow)*len,y2=m.y-sin(a-prow)*len},
					{x1=m.x,y1=m.y,x2=m.x-cos(a+prow)*len,y2=m.y-sin(a+prow)*len},
					{x1=m.x-cos(a+prow)*len,y1=m.y-sin(a+prow)*len,x2=m.x-cos(a-prow)*len,y2=m.y-sin(a-prow)*len},
				},
				-- rocket point
				{x=m.x-cos(a)*(len+1),
				y=m.y-sin(a)*(len+1)},
				--prow
				{x=m.x,y=m.y}
			end,
			
			spawn=function(_ENV)
				if not playing then return end
--				a,dx,dy,gun=-.1,0,0,0
				a,dx,dy=-.1,0,0
				y=id==0 and 32 or 16
				x=id==0 and 64 or 72
				spawnticks=16
				enabled=true
			end,
			
			death=function(_ENV,cause)
				local lines=coords(_ENV)				
				for l in all(lines) do
					l.dx,l.dy=cause.dx or dx,cause.dy or dy
					l.midx,l.midy=(l.x1+l.x2)/2,(l.y1+l.y2)/2
					l.dr=rnd(.025) l.r=atan2(l.x2-l.x1,l.y2-l.y1)
					local ang=atan2(l.midx-x,l.midy-y)
					l.dx+=cos(ang)*.25 l.dy+=sin(ang)*.25
					l.t=rndr(120,150)
					add(deathlines,l)
				end
				
				local s = 4 --dist spread
				local ds=.1 --speed spread
				for i=1,10 do
					local z = {x=x+rndr(-s,s),
																y=y+rndr(-s,s),
																dx=(cause.dx or dx)+rndr(-ds,ds),
																dy=(cause.dy or dy)+rndr(-ds,ds)}
					local ang=atan2(z.x-x,z.y-y)
					z.dx+=cos(ang)*0.1
					z.dy+=sin(ang)*0.1
					z.t=rndr(120,150)
					add(deathpnts,z)
				end
			end,
			
			renderdeath=function(_ENV)
				color(pcolor)
				for l in all(deathlines) do
					l.midx+=l.dx
					l.midy+=l.dy
					l.r+=l.dr
					line(l.midx-cos(l.r)*3,
										l.midy-sin(l.r)*3,
										l.midx+cos(l.r)*3,
										l.midy+sin(l.r)*3)
					l.t-=1
					if l.t<0 then del(deathlines,l) end
				end
				for z in all(deathpnts) do
					z.x+=z.dx z.y+=z.dy
					pset(z.x,z.y)
					z.t-=1
					if z.t<0 then del(deathpnts,z) end
				end
			end,
		},{__index=_ENV}))
	end
end

function blink_anim(lines)
	local grays,duration={7,6,13,1},8
	while duration>=0 do
		local pct=(8-duration)/8
		local idx=ceil(pct*#grays)
		for l in all(lines) do
			line(l.x1,l.y1,l.x2,l.y2,grays[idx])
		end
		duration-=1
		yield()
	end
end

--always returns either p1 or p2
function closestplayer(t)
	if not ps[2].playing then return ps[1] end
	if not ps[2].enabled then return ps[1] end
	if not ps[1].enabled then return ps[2] end	
	return distt(t,ps[1])<distt(t,ps[2]) and ps[1] or ps[2]
end
-->8
--title screen
function title_setup()
--	tick=0
	sfx(37)
	clearlevel()
	inner.enabled=true
	local a=rnd()
	add(lz,{a=a,x=64+cos(a)*63,y=64+sin(a)*63,speed=.0025,parts={index=0}})
	h:spawn()
	for i=1,5 do
		local f={}
		f.tick,f.max=flr(rnd(100)),12
		f.growgoal=240 --grow rate
		f.br=1000 --bud rate
		local r={}
		local d,a=12+rnd(63-24),rnd()
		r.x=64+cos(a)*d r.y=64+sin(a)*d r.r=9
		r.growcount=rnd(f.growgoal) r.hit=-100
		add(f,r)
		add(fs,f)
	end
	local z=flr(rnd(10))+3
	for i=1,z do
		local r,a,d={},rnd(),rnd(64-24)+12
		r.x,r.y=64+cos(a)*d,64+sin(a)*d
		local a2,spd=rnd(),(rnd(1.25)+.5)/2
		r.dx,r.dy=cos(a2)*spd,sin(a2)*spd
		r.r,r.enabled,r.hit=3+rnd(8-3),true,-10
		add(rs,r)
	end
	yield()
	
	local haspressed,c=false,0
	
	while c<30 or not ((btn(❎) or btn(🅾️)) and haspressed) do
		c+=1
--give the bomb something to chase
		if rnd()>.95 then 
			ps[1].x,ps[1].y=rnd(128),rnd(128)
		end

		pal(7,0)
		sspr(65,0,51,39,39,18)
		pal()

		--difficulty choose
		if haspressed then
			if btnp(⬅️) or btnp(⬇️) then
				difficulty=mid(1,difficulty-1,3)
			end			
			if btnp(➡️) or btnp(⬆️) then
				difficulty=mid(1,difficulty+1,3)
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
		else
			cprint("press ❎",64,114,1)
			if btnp()~=0 then
				haspressed,c=true,0
			end
		end
		
		if btnp()>255 then --bitfield where high bits are p2
			ps[2].playing=not ps[2].playing
		end
		
		print("2p join"..(ps[2].playing and "!" or "?"),
			96,0,ps[2].playing and 12 or 1)
		
		color(1)
		print("c"..smallcaps("asey"),108,117)
--		print(smallcaps("@").."c"..smallcaps("asey"),104,117)
		print("l"..smallcaps("abrack"),100,122)

		print(smallcaps("v").."."..version,1,122)
		yield()
	end
	dset(2,difficulty)
	sfx(37,-2)
	seconds,minutes=0,0
	
	-- play tau 0 if noob or on practice difficulty
	if difficulty==1 or dget(3)==0 then lvl=0 else lvl=1 end

	mulligans=mulldiff[difficulty]
	extralives=mulligans
	state="wipe"
	wipe=cocreate(wipe_anim)	
end
-->8
-- boss
boss =
setmetatable({
enabled=false,
r=3,steadyx=64,steadyy=64,lasthit=-100,
spawnnum=3,finalsize=10,
growdur=160,detht=0,
floor={x=64,y=64,r=22},
	
update=function(_ENV)
	if not enabled then return end
	local targetplayer=closestplayer(boss)
	local towardplayer=atan2(targetplayer.x-64,targetplayer.y-64)
	if state=="spawn" then
		if #bulges<spawnnum then
			local b={}
			b.r,b.finalr=0,5+rnd()*5
			local a=rnd()
			b.x,b.y=64+cos(a)*8,64+sin(a)*8
			b.tx,b.ty=b.x,b.y --target position it can vibrate around
			add(bulges,b)
			state="grow"
			start=0
		else
			state="warn"
			start=0
		end
	elseif state=="grow" then
		if start<growdur then
			start+=1
			local pct=start/growdur
			local spawnling=bulges[#bulges]
			spawnling.r=pct*spawnling.finalr
		else
			state="spawn"
		end
	elseif state=="warn" then
		if start<60 then
			start+=1
			local pct=start/60
			for bulge in all(bulges) do
				local a,d=rnd(),pct*3
				bulge.x,bulge.y=bulge.tx+cos(a)*d,bulge.ty+sin(a)*d
			end
		else
			state="fire"
		end
	elseif state=="fire" then
		for bulge in all(bulges) do
			local spd=(rnd(1.25)+.5)/2
			local a=towardplayer+rndr(-.1,.1)
			add(rs,{x=bulge.tx,y=bulge.ty,
											dx=cos(a)*spd,dy=sin(a)*spd,
											r=bulge.r,enabled=true,hit=-10})
			bulges={}	
		end
		state="spawn"
	elseif state=="intro" then
		if start<120 then
			start+=1
			r=finalsize*start/120
		else
			state="spawn"
			start=0
		end
	end
	if state~="intro" then
		local rx,ry=64+cos(towardplayer)*7,64+sin(towardplayer)*7
		local dx,dy=rx-steadyx,ry-steadyy
		dx*=.05 dy*=.05
		steadyx+=dx steadyy+=dy
			--bob around
		local modx=cos(time()/4+.7)*3
		local mody=cos(time()/6)*3
			--final pos	
		x,y=steadyx+modx,steadyy+mody
	end
end,

render=function(_ENV)
	if not enabled then return end

	for bulge in all(bulges) do
		circfill(bulge.x,bulge.y,bulge.r,0)
		circ(bulge.x,bulge.y,bulge.r,9)
	end
	local c=tick-lasthit<10 and 7 or 15
	local hit=tick-lasthit<10
	if hit then 
		if tick%8<4 then
			pal(14,8)
		end
	end
	
	local targetplayer=closestplayer(boss)
	local top=atan2(targetplayer.x-x,targetplayer.y-y)
--	local x1,y1,x2,y2=0,52,20,72
	local x1,y1,x2,y2=22,17,42,38
	palt(0,false)
	palt(10,true)
	local wid=x2-x1
	local scale=wid*(1-detht)
	if detht>.33 then pal(14,2) end
	if detht>.66 then pal(14,1) end
	sspr(x1,y1,wid,wid,
	x-scale/2,y-scale/2,
	scale,scale)
	palt()

	-- if boss dying,center eye elements
	local lidr,pupr=detht==0 and 2 or 0,detht==0 and 5 or 0

	circ(x+cos(top)*lidr,y+sin(top)*lidr,(r-4)*(1-detht),14)
	if detht<.33 and detht<1 then
		spr(20,x-3+cos(top)*pupr,y-3+sin(top)*pupr)
	else
		local r=4*(1-detht)-1
		circ(x-r/2,y-r/2,r,8)
	end
	pal(cp)
end,

spawn=function(_ENV)
	enabled,bulges=true,{}
	x,y,r,hp=64,64,10,360
	state,start,detht="spawn",0,0
end,
},{__index=_ENV})
-->8
--intro

cs={}
tick=0
i=0

function introdraw()
	tick+=1

	for c in all(cs) do
		c.r*=1.1
		c.p+=.01
	end
	
	if cs[1] and cs[1].r>64 then 
		deli(cs,1) 
	end

	if tick%15==0 and i<6 then
		i+=1
		add(cs,{r=1,p=rnd(),id=i})
	end

	cls()
 for z=#cs,1,-1 do
 	local sx = 64+cos(cs[z].p)*15
 	local sy = 64+sin(cs[z].p)*15
 	circfill(sx,sy,cs[z].r, 0 | 0x1800)  	
		if cs[z].id==6 then
			sspr(
				1,17, --source coord
				19,19, --source w/h
				sx-cs[z].r,sy-cs[z].r,--destination coord
				cs[z].r*2,cs[z].r*2 -- destination w/h
			)
		else
			circ(sx,sy,cs[z].r, 5 | 0x1800)
		end			  	
 end 

	if tick==180 then
		_update60=_mainupdate
		_draw=_maindraw
		tick=0
		title=cocreate(title_setup)
	end
end
__gfx__
000000000000000000000000000000000000000000c00c0000000000000000000000000000000000000000000000000000008000000000000000000000000000
00000000000000000000000000000000000000000c0cc0c000000000000000000000000000000000000000000000000000887800000000000000000000000000
0070070000000000000000000000000000000000c0c66c0c00000000000000000000000000000888800000000000000008777800000000000000000000000000
00077000000000000008000000000000000000000c6666c000000000000000000000000000088777780000000000000088777800000000000000000000000000
00077000000000000080800000000000000000000c6666c000000000000000000000000008877777778000000000000087777800000000000000000000000000
0070070000000000000800000000000000000000c0c66c0c00000000000000000000000887777777778000000000000887777800000000888880000000000000
00000000000000000000000000000000000000000c0cc0c000000000000000000000008777777777788000000000000877877800000008777780000000000000
000000000000000000000000000000000000000000c00c0000000000000000000000008777777777780000000000008877877800000087777778000000000000
aeaaaaaaaaeaaaaaaaaeaaaaaaaaeaaa000800000e00000000700000eaaaaaae0000087777777777780088880000008777877800000877777778000000000000
aaeaaaaeaaaeaaaaaaaaeaaaaaaaaeaa0080800000e0000e00700000aeaaaaea0000087777788777800877788000088778877800008777777778000000000000
aaeeeeeaaaeeeeaeaaeeeeaaaeeeeeaa08eee80000eeeee007770000aaeeeeaa0000877778887777800877778000087778877800008777777780000000000000
aae00eaaaae00eeaaee00eaeeae00eaa80e8e08000e80e0077077000aae00eaa0000877880877778008777778000087780877800087777778800000000000000
aae00eaaaee00eaaeae00eeaaae00eae08eee80000e00e0070007000aae00eaa0000888000877780008777778000877780877800877777780000000000000000
aeeeeeaaeaeeeeaaaaeeeeaaaaeeeeea008080000eeeee0000000000aaeeeeaa0000000008777780087777778000877788877800877777800000000000000000
eaaaaeaaaaaaeaaaaaaeaaaaaaeaaaaa00080000e0000e0000000000aeaaaaea0000000008777800087777778008777777777808777778000000000000000000
aaaaaaeaaaaaaeaaaaaaeaaaaaaeaaaa00000000000000e000000000eaaaaaae0000000087777800877787778008777777777808777788888880000000000000
00000000000000000000000000000000000000000000000000000000000000000000000087778000877787778088777777777887777887777780000000000000
000000000e0e0e00000000aaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000877778008777787778087777777777887778877777778000000000000
0000000eeeeeeeee000000aaaaaaaaeaeaeaaaaaaaa0000000000000000000000000008777780008777887778087777777777877788777777778000000000000
0000ee0ee0000ee00e0000aaaaaaeeeeeeeeeaaaaaa0000000000000000000000000008777800008778087778877778888777877788777787778000000000000
00000ee00000000eee0000aaaeeaee0000eeaaeaaaa0000000000000000000000000087777800087778087778877780008777877800888887778000000000000
000ee000000000000ee000aaaaee00000000eeeaaaa0000000000000000000000000087778000087778887778877780008777877800008777788000000000000
00eee0000eeee0000e0000aaee000000000000eeaaa0000000000000000000000000877778000877777777778777800008777877888887777780000000000000
000e000ee0000ee000e000aeee000000000000eaaaa0000000000000000000000000877780000877777777778777800008777877788777777800000000000000
00ee000e000800e000ee00aae00000000000000eaaa0000000000000000000000008777780000877777777778778000008777877777777778000000000000000
0ee000e00080800e000ee0aee00000000000000eeaa0000000000000000000000008777800008777777777778888000008777887777777780000000000000000
00e000e008eee80e000e00ee0000000000000000eea0000000000000000000000087777888808777777777778000000008778087777777800000000000000000
0ee000e080e8e08e000e00ae0000000000000000eaa0000000000000000000000087778887787777777887778000000000878008777888000000000000000000
00e000ee08eee8ee000ee0ee0000000000000000eaa0000000000000000000000087777777787777888087778000000000080000888000000000000000000000
0eee000ee0808ee000e000ae0000000000000000eea0000000000000000000000877777777787778000087778000000000000000000000000000000000000000
000e000e0ee8e00000ee00eee00000000000000eaaa0000000000000000000000877777777877780000087778000000000000000000000000000000000000000
0000e0000eeee0000e0000aae00000000000000eeaa0000000000000000000000877777777877780000087778000000000000000000000000000000000000000
0000e000000000000ee000aaae000000000000eaaaa0000000000000000000000087777788777780000087778000000000000000000000000000000000000000
00000ee00000000ee00000aaae000000000000eeaaa0000000000000000000000087788808777800000008788000000000000000000000000000000000000000
0000ee0ee0000ee0ee0000aaaaee00000000eeaaaaa0000000000000000000000088800008777800000000800000000000000000000000000000000000000000
0000000eeeeeee0e000000aaaeeaee0000eeaeeaaaa0000000000000000000000000000087778000000000000000000000000000000000000000000000000000
000000000e0e0e00000000aaaaaaeeeeeeeaeaaaaaa0000000000000000000000000000087788000000000000000000000000000000000000000000000000000
0000000000000000000000aaaaaaaaeaeaeaaaaaaaa0000000000000000000000000000087780000000000000000000000000000000000000000000000000000
0000000000000000000000aaaaaaaaaaaaaaaaaaaaa0000000000000000000000000000087800000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000
00000000000000000000000000088880000000088800000000000880000000000000000000000000888800000000000000000000000000000000000000000000
00000000000000000000000008800008000000800880000000008888000000000000000000000088000888000080000000088800008888000000000000000000
00000000000000000000000080008888000008000008000000080008000000000000088880000800000000800888800000800808888000880088888888880000
00000000000000000000000800008000000008000008000000800000800088800008880008800800088000808000800008000808000008880080000000008800
00000000000000000000008000080088880080088000800000800000808800080088000088808000088000800800080008000808008888000800088888800080
00000000000000000000008000880880080080088000800008000000808000080080088880008000808000800800080080008008008000000800080008000080
00000000000000000000008000800800080800088000080008008800880080008080080000008000888000800800008080080008008000000800080880000880
00000000000000000000008008800800080800080000080080008800080088008080088888008000880000800080008800080008008000000800088800088000
00000000000000000000080008008000808000000000080080080800000808008080000008000800000008000008000800800008000888800800000008800000
00000000000000000000080008008000808000000880008800080800008008000880088888000880000080000008000008000008000008800800000008000000
00000000000000000000080008080008080000888880008880800880888008888080080000000008888800000000800008000008008888000080008800880000
00000000000000000000008008800008080008000080008088800088800000000080088880000000000000000000880880000008008000000088008880088000
00000000000000000000008008800080080080000008888000000000000000000080000080000000000000000000088800000008008888000008008080008800
00000000000000000000008000000800800080000000080000000000000000000080000880000000000000000000000000000008000008800008008080000800
00000000000000000000000800008000888880000000000000000000000000000008888000000000000000000000000000000008000088800008888088008800
00000000000000000000000088880000088000000000000000000000000000000000000000000000000000000000000000000000888800000000000000880000
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
00000000000000000000000000000000066000000000000000000000000000000000000000000000000000000000086600000000000000000000000000000000
000000000000000000000000000000066000000000000000000000000000000000000000000000000000000000008b8066000000000000000000000000000000
00000000000000000000000000000060000000000000000000000000000000000000000000000000000000000008eee800600000000000000000000000000000
00000000000000000000000000006600000000000000000000000000000000000000000000000000000000000080e8e080066000000000000000000000000000
00000000000000000000000000060000000000000000000000000000000000000000000000000000000000b0b0b8eee8b0000600000000000000000000000000
0000000000000000000000000060000000000000000000000000000000000000000000000000000000000b000b008b800b000060000000000000000000000000
00000000000000000000000066000000000000000000000000000000000000000000000000000000000000000000080000000006600000000000000000000000
00000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000
0000000000000000000000600000000000000000000000000000000000000000000000000000000000b0b0b0b0b0b0b0b0b0b000006000000000000000000000
000000000000000000000600000000000000000000000000000000000000000000000000008000000b000b000b000b000b000b00000600000000000000000000
00000000000000000000600000000000000000000000000000000000000000000000000088080000000000000000000000000000000060000000000000000000
00000000000000000006000000000000000000000000000000088880000000000000000800080000000000000080000000000000000006000000000000000000
00000000000000000060000000000000000000000000000008800008000000000000008800080000b0b0b0b0b8b8b0b0b0b0b0b0000000600000000000000000
000000000000000006000000000000000000000000000008800000008000000000000080000800000b000b008eee8b000b000b00000000060000000000000000
00000000000000006000000000000000000000000000088000000000800000000000088000080000000088888e8e080000000000000000006000000000000000
00000000000000060000000000000000000000000000800000000008800000000000080080080000000800008eee800000000000000000000600000000000000
00000000000000060000000000000000000000000000800000000008000000000000880080080000b080000008b8b0b0b0b0b0b0000000000600000000000000
000000000000006000000000000000000000000000008000000000080088880000008000800800000800000008800b000b000b00000000000060000000000000
00000000000006000000000000000000000000000000800008800080080008800008800880080000800000000800000000000000000000000006000000000000
00000000000060000000000000000000000000000000800888000080080000800008000880080000800000008000000000000000000000000000600000000000
0000000000006000000000000000000000000000000008808000080080000080000800808008000800000088b0b0b0b0b0b0b0b0000000000000600000000000
00000000000600000000000000000000000000000000000080008000800000800080008080080080000008900b000b000b000b00000000000000060000000000
00000000006000000000000000000000000000000000000800008008000000800080008880080080000080099000000000000000000000000000006000000000
00000000006000000000000000000000000000000000000800080008000000800800000000080800000800000908000000000000000000000000006000000000
0000000006000000000000000000000000000000000000800008008000800080080000000008080000888888809080b0b0b00000000000000000000600000000
00000000060000000000000000000000000000000008008000800b8000800080880000000008800008800000889ee8000b000000000000000000000600000000
000000006000000000000000000000000000000000808800008008000080008080000000000880008800000008e9e08000000000000000000000000060000000
000000006000000000000000000000000000000008ee8000080008000880008080000000000800088000000008e9e80000000000000000000000000060000000
000000060000000000000000000000000000000080e8800080b0b80080800088000088880008000880000800088980b000000999990000000000000006000000
000000060000000000000000000000000000000008e800008b0080008b80008800080008000800800888880008090b0000099000009900000000000006000000
00000060000000000000000000000000000000000088000800008000888000880008000800080080000800008809000000900000000090000000000000600000
00000060000000000000000000000000000000000080000800080000000000800080000800080088888000008090000009000000000009000000000000600000
000006000000000000000000000000000000000000800080b0b80000000000800080000800080008800000080090000009000000000009000000000000060000
0000060000000000000000000000000000000000080000800b080000000000800800000800080000000000800900000090000000000099900000000000060000
00000600000000000000000000000000000000000800080000800000000000888800000800088000000008099000000090000080009900999000000000060000
00006000000000000000000000000000000000008000088888800000000000800000000800808000000089900000000090000808009000909000000000006000
0000600000000000000000000000000000000000800088800800000008800080b000000088000800088800000000000090000990090080999990000000006000
000060000000000000000000000000000000000080000000080000888b8000800000000000000088800000000000000090000009990808900900000000006000
00060000000000000000000000000000000000080000000008000800008000800000000000000000000000000000000009000000090089000900000000000600
00060000000000000000000000000000000000080000000080008000008000800000000000000000000000000000000009000000009009009000000000000600
000600000000000000000000000000000000000800000000800080b0b0800080b000000000000000000000000000000000900000009990099000000000000600
00060000000000000000000000000000000000088000008800008b000b8000800000000000000000000000000000000000099000009999900000000000000600
00600000000000000000000000000000000000808008880800080000000888000000000000000000000000000000000000000999990000000000000000000060
00600000000000000000000000000000000000088888000800080000000000000000000000000000000000000000000000000000000000000000000000000060
0060000000000000000000000000b0b0b00000008080b0800080b0b0b0b0b0b00000000000000000000000000000000000000000000000000000000000000060
0060000000000000000000080b000b000b00000008000b8008800b000b000b000000000000000000000000000000000000000000000000000000000000000060
00600000000000000000008080000000000000000000008008000000000000000000000000000000000000000000000000000000000000000000000000000060
0060000000000000000008eee8000000000000000000008080000000000000000000000000000000000000000000000000000000000000000000000000000060
0600000000000000000080e8e080b0b0b0b0b0b000000008b0b0b0b0b00000000000000000000000000000000000000000000000000000000000000000000006
0600000000000000000008eee8000b000b000b00000000000b000b00000000666660000000000000000000000000000000000000000000000000000000000006
06000000000000000000008080000000000000000000000000000000000006000006000000000000000000000000000000000000000000000000000000000006
06000000000000000000000800000000000000000000000000009000000060000000600000000000000000000000000000000000000000000000000000000006
06000000000000000000b0b0b0b0b8b0b0b0b0b0b000999000990000000600000000060000000000000000000000000000000000000000000000000000000006
060000000000000000000b000b008b800b000b000b99000999000000006000000000006000000000000000000000000000000000000000000000000000000006
0600000000000000000000000008eee8000000000090000090000000006000000000006000000000000000000000000000000000000000000000000000000006
0600000000000000000000000080e880800000000900800009000000006000000000006000000000000000000000000000000000000000000000000000000006
060000000000000000b0b0b0b0b8b8b8b0b0b0b0b9b8080009000000006000000000006000000000000000000000000000000000000000000000000000000006
060000000000000000080b000b008eee8b000b000900800009000000006000000000006000000000000000000000000000000000000000000000000000000006
06000000000000000080800000080e8e080000000090000090000000088600000000060000000000000000000000000000000000000000000000000000000006
060000000000000008eee80000008eee800000080099000990000088800060000000600000000000000000000000000000000000000000000000000000000006
060000000000000080e8b0b0b0b0b8b8b0b0b0b0b0b09990000088000000b6000006b0b0b0000000000000000000000000000000000000000000000000000006
060000000000000008eeeb000b000b800b000beeeb0000000088000000000b6666600b000b000000000000000000000000000000000000000000000000000006
06000000000000000080800000000000000080e8e080000088000000000000000000000000000000000000000000000000000000000000000000000000000006
00600000000000000008000000000000000008eee800008800000000000000000800000000000000000000000000000000000000000000000000000000000060
00600000000000000000b0b0b0b0b0b0b0b0b0b0b0b888000000000000b0b0b08080b0b0b0b00000000000000000000000000000000000000000000000000060
006000000000000000000b000b000b000b000b080b800000000000000b000b08eee80b000b000000000000000000000000000000000000000000000000000060
0060000000000000000000000000000000000008800000000000000000000080e8e0800000000000000000000000000000000000000000000000000000000060
0060000000000000000000000000008000000880000000000000000000000008eee8000000000000000000000000000000000000000000000000000000000060
006000000000000000000000b0b0b8b8b0b8b0b0000000000000000000b0b0b08080b0b0b0b00000000000000000000000000000000000000000000000000060
0006000000000000000000000b008eee8b000b0000000000000000000b000b0008000b000b000000000000000000f00000000000000000000000000000000600
00060000000000000000000000080e8e0800000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000600
00060000000000000000000000008eee800000000099999000000000000000000000000000000000000000000fffff0000000000000000000000000000000600
0006000000000000000000000888b8b8b0b0000009000009000000000000b0b0b0b0b0b0b000000000000000f0f88f0000000000000000000000000000000600
00006000000000000000000880000b800b000000900000009000000000000b000b000b000b0000000000000000f88f0f00000000000000000000000000006000
000060000000000000000880000000000000000900000000090000000000000000000000000000000000000000fffff000000000000000000000000000006000
000060000000000000088000000000000000009000000000009000000000000000000000000000000000000000f0000000000000000000000000000000006000
0000060000000000088000000000000000000090000800000090000000000000b0b0b0000000000000000000000f000000000000000000000000000000060000
00000600000000888000000000000000000000900080800000900000000000000000000000000000000000000000000000000000000000000000000000060000
00000600000088000000000000000000000000900008000000900000000000000000000000000000000000000000000000000000000000000000000000060000
00000060008800000000000000000000000000900000000000900000000000000000000000000000000000000000000000000000000000000000000000600000
00000060880000000000000000000000000000090000000009000000000000000000000000000000000000000000000000000000000000000000000000600000
00000088000000000000000000000000000000009000000090000000000000000000000000000000000000000000000000000000000000000000000006000000
00000006000000000000000000000000000000000900000900000000000000000000000000000000000000000000000000000000000000000000000006000000
00000000600800000000000000000000000000000999999000000000000000000000000000000000000000000000000000000000000000000000000060000000
00000000800000000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000060000000
00000000060000000000000000000000000000000900000000000000000000000000000000000000000000000000000000000000000000000000000600000000
00000000060000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000600000000
00000000006000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000006000000000
00000000006000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000
00000000000608000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000
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
00000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000600000010001100000000000000000
00000000000000000000000000000006600000000000000000000000000000000000000000000000000000000000000066000000101010000110011011101010
00000000000000000000000000000000066000000000000000000000000000000000000000000000000000000000006600000000101010001010100011001110
00000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000660000000000100010001110001010000010
00000000000000000000000000000000000006600000000000000000000000000000000000000000000000000066000000000000011001101010110001101100
00000000011101110000000000000000000000066000000000000000000000000000000000000000000000006600000000001000000000000000000000000000
01010000000101010000000000000000000000000666000000000000000000000000000000000000000006660000000000001000011011001100011001101010
01010000011101110000000000000000000000000000666000000000000000000000000000000000006660000000000000001000101011001010101010001100
01110000010001010000000000000000000000000000000666600000000000000000000000000066660000000000000000001000111010101100111010001010
00100010011101110000000000000000000000000000000000066666600000000000000066666600000000000000000000001110101011101010101001101010
00000000000000000000000000000000000000000000000000000000066666666666666600000000000000000000000000000000000000000000000000000000

__sfx__
0005000005650096500e65013650176502165000000000001d6001e600216000000024600286002e6002f600000000000000000000001c6001d6001e6001f600000001f600206000000020600206000000021600
000400000725008250082500a2500c2500f250132501d250232502c250332503e2500020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
0006000a0b6100b6100b6100b6100a6100a6100b6100b6100b6100d6100d6000d6000d6000d6000d6000d60000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
011400001140011400114001140011400114001340016400114001340016400164001140011400114001140000400274002740027400274000040000400004000040000400004000040000400004000040000400
011400000645014400114000000006450084500545000000064501440011400000000645008450054500000006450144001140000000064500845005450000000645014400114000000006450084500545000000
000800000f5501b550275503355000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
01020d123550033500305002e5002e5002b5002950027500225001b5001650013500115000f5000f5000f5000f5000f5000050000500005000050000500005000050000500005000050000500005000050000500
010200003f5103c5103c5103a5103551035510335102e5102b5102b51029510275102451022510225101f5101d5101b510185101651013510115100f5100f5100c5100c5100a5100a51007510055100351003510
000200000576022760297601d76007760077600070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010600003a4513745135451334511d4510f4510740100401074010040100401004010040100401004010040100401004010040100401004010040100401004010040100401004010040100401004010040100401
0108000005050070400a030130201f010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000005450074400a630136201f410004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
000200000571022710297101d71007710077100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01180000000530c0531805324053300533c0533f05300000000530c0531805324053300533c0533f05300000000530c0531805324053300533c0533f05300000000530c0531805324053300533c0533f05300000
011800000065000000000000000000650000000000000000006500000000000000000065000000000000000000650000000000000000006500000000000000000065000000000000000000650000000000000000
011800000505006050050500605005050060500505006050050500505006050050500605005050060500505006050050500605005050060500505006050050500505006050060500505005050060500505006050
011800002a0532a0530000329053290530000300003000032a0532a0530000329053290530000300003000032a0532a0530000329053290530000300003000032a0532a053000032905329053000030000300003
011800001505113051110511c0511f0511d0511c0511a0511a0501a0501a0501a0501a0501a0501a0501a05000000000010000100001000010000100001000010000000000000000000000000000000000000000
011800001605114051120511d051200511e0511d0511b0511b0501b0501b0501b0501b0501b0501b0501b05019000020010200102001020010200102001020010200102001020010200102001020010200102001
01080000000000010300103001030010318113171131612315123121330d133061430214301153001030010300103001030010300103001030010300103001030010300103001030010300103001030010300103
01060000000000000000000000000c0100c0100c0100c0200c0200c0200c0200c0200c0300c0300c0300c0400c0400c0500c05000000000000000000000000000000000000000000000000000000000000000000
000800200c0100c0100c0100c0100c0100c0100c0100c0200c0200c0200c0200c0200c0300c0300c0300c0400c0400c0500c0500c0500c0500c0500c0500c0500c0500c0500c0300c0300c0200c0200c0200c010
0110000000500005003755000500005000050030550005000050000500005000050000500005003a550375000050000500005000000000000005003c5502e50000500005003c50000500005003a5003f55000000
01100000000000000024550295002b5002e500000000000037500000003c5500000000000000000000000000000003f5002255000000000000000000000000003f500000002455000000000003f5003055000000
000800200c0100c0100c0100c0100c0100c0100c0100c0200c0200c0200c0200c0200c0300c0300c0300c0300c0300c0300c0300c0300c0300c0300c0300c0300c0300c0300c0300c0300c0200c0200c0200c010
01080000120500c0500c0500c05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000180201e0201f0201f0201f020270003c00037000350003500033000300002e0002b00029000290002700027000240002400022000220001f0001d0001d0001b0001b0001b0001b000000000000000000
010a000030624306242e6242e6242e6242b6242b6242962429624246242262422624226241b6241b6241b6241b6241b6241b6241662413624136241362413624136240c6240c6240c6240c6240a6240a62405624
010800000f05009050090500905000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01020000027700d770137700770002700017000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
01020000027500d7501375007700027700c7701c77026770137700f7700c7700a7700877006770057700477003770027700177000770007000070000700007000070000700007000070000700007000070000700
000200002c01025010200101c01019010170101401012010100100e0100b010090100701006010050100401004010030100301003010030100301002010010100101000010000100001000010000100001000010
000200001a7101a7201a7301a7301a7001a7101a7301a7701a7601a7501a7401a7301a7201a710007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c0000030540305003050030500f0050c0000f0050c000030540305003050030500f0000f0000f0000c000010540105001050010500f0000f0000f0000c000010540105001050010500f0000f0000f0000c000
010c00000205402050020500205000000000000000000000020540205002050020500000000000000000000002054020500205002050000000000000000000000205402050020500205000000000000000000000
010c00000503405030050300503006000060000600006000050340503005030050300000000000000000000005034050300503005030060000600006000060000703107031070300703000000000000000000000
011400000645014400114000000006450084500545000000064501440011400000000645008450054500000006450144001140000000064500845005450000000645014400114000000006450084500545000000
011400001645013450134500a4500a4500a45007450074500a4500a4500a4501d4503340033400004000040000400004000040000400004000040000400004000040000400004000040000400004000040000400
001000002803428030280302803028030280302803028030280302803028030280302803028030280302803028030280302803028030280302803028030280302803028030280302803028030280302803028030
001000002d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d0302d030
__music__
00 0e0f4344
00 0e0f4344
02 0e110f44
01 31424344
02 30424344
00 36354344
00 41424344
00 41424344
01 1a1b4244
00 1a1b1c44
00 1a1b1c44
00 401b1d44
00 1b1e4344
02 1b1f4344
00 41424344
00 26294344
00 41424344
00 41424344
00 41424344
00 41424344
01 22234344
02 22244344

