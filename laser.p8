pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- lasers
-- casey labrack
-- todo:
--  bg
--  nicer shield effect (draw arc manually?)
-- 	fix flowers spawn out of bounds
-- 	starfield flyin
--  timing or lap based enemy
--  multiple bullets?
--  bigger min size for flowers
--  player animations
--  gameover animations
--  fuzziness

function plines(this) 
	local m={x=p.x+cos(p.a)*2,y=p.y+sin(p.a)*2}
	local prow=.075
	local len=6
	local aft=len-2
	return {
		{x1=m.x,y1=m.y,x2=m.x-cos(p.a-prow)*len,y2=m.y-sin(p.a-prow)*len},
		{x1=m.x,y1=m.y,x2=m.x-cos(p.a+prow)*len,y2=m.y-sin(p.a+prow)*len}
	}
--	line(m.x,m.y,m.x-cos(p.a-prow)*len,m.y-sin(p.a-prow)*len,7)
--	line(m.x,m.y,m.x-cos(p.a+prow)*len,m.y-sin(p.a+prow)*len,7)
end

p = {x=80,y=30,dx=0,dy=0,
					a=.75,t=.25,rt=.05,r=3,friction=.92,
					hop=25,charge=0,fullcharge=90,
					enabled=false,controllable=true,
					thrusting=false,
					gun=0,gunfull=160,gunfail=false,gunfailtick=0,
					flipready=10,fliplast=0,
					lines=plines}
ps= {} --player death particles
lz= {} --lasers
zs= {} --safe zones
hs= {} --homing bombs
as= {} --animations (coroutines)
a2= {}
fs= {} --flowers
rs= {} --roids
b = {x=0,y=0,dx,dy,a=0,r=2,speed=5,enabled=false}
w = {enabled=false,r=0}
inner = {x=64,y=64,r=6}
outer = {x=64,y=64,r=63}
lvl=0
extralives=3
tick=0
scoreboxes={{0,0},{7,0},{14,0},{21,0}}
state="wiping"
gameover={is=false}
cp=dp--current pallete

function _init()
local a=cocreate(wipe)
add(as,a)
end

function _update()
tick+=1

-- do animations
for a in all(as) do
	if costatus(a)!="dead" then coresume(a)
	else del(as,a) end
end

if state=="setup" then
	return
end

if p.enabled then
	p.charge+=1 p.gun=min(p.gun+1,p.gunfull)
	if btn(➡️) then p.a=p.a-p.rt end
	if btn(⬅️) then p.a=p.a+p.rt end
	if btn(⬆️) and p.charge>p.fullcharge then 
		p.x+=cos(p.a)*p.hop
		p.y+=sin(p.a)*p.hop
		p.charge=0
	end
	if btn(⬇️) then	
--	p.dx=0 p.dy=0
		if tick-p.fliplast>p.flipready then
		 p.a+=.5
		 p.fliplast=tick
	 end
	end
	if btn(🅾️) then 
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
	if btn(❎) and not b.enabled then
		if p.gun==p.gunfull then
			b.enabled=true
			b.x=p.x b.y=p.y b.a=p.a
			b.dx=cos(b.a)*b.speed b.dy=sin(b.a)*b.speed
			sfx(11)
		else 
			if tick-p.gunfailtick>10 then
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
					k.r=2	k.growcount=0
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
end

-- safe zones
for z in all(zs) do
	if z.shrinking then
		z.t-=z.speed
		if z.t<2 then
			z.a=rnd(1) z.t=32
			z.x=64+cos(z.a)*63 z.y=64+sin(z.a)*63
			z.shrinking=false
		end
	end
	if touching(p,z) then z.shrinking=true end
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
		if touching(p,z) then vulnerable=false break end
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
if b.enabled then
	local x1=b.x 
	local y1=b.y
	for i=1,5 do
		b.x=x1+b.dx*i/5
		b.y=y1+b.dy*i/5
		for f in all(fs) do --flowers
			for l in all(f) do --leaves
				if touching(b,l) then
					b.enabled=false
					l.r-=2
					l.growcount=0
					if l.r<3 then	
						del(f,l)
						if #f==0 then del(fs,f) end 
					end
					goto donebullet
				end
			end
		end
		for v in all(rs) do --roids
			if touching(b,v) then
				b.enabled=false
				v.r-=2
				if v.r<2 then	del(rs,v) end
				goto donebullet
			end
		end
		for h in all(hs) do --homing
			if touching(h,b) then
				b.enabled=false
				h.enabled=false
				h.timer=60
				h.dx+=b.dx/4	h.dy+=b.dy/4
				goto donebullet
			end
		end
		if touching(inner,b) or not touching(outer,b) then
			b.enabled=false
			goto donebullet
		end
	end
end
::donebullet::

--level win
if #rs==0 and #fs==0 and p.enabled and state=="running" then
	state="wiping"
	extralives=3
	if lvl>#lvls then lvl=1 end
	local a=cocreate(wipe)
	add(as,a)
end
end

function died(cause)
	if state~="running" then return end
	sfx(2,-2)
	sfx(13)
	p.enabled=false
	local d=cocreate(deathparticles)
	coresume(d,cause)
	add(a2,d)
	extralives-=1
	if extralives<0 then lvl=1 end
	state="death"
--	waiting=cocreate(anykey)
--	coresume(waiting,60)
	local a=cocreate(death)
	coresume(a,15,30)
	add(as,a)
end

function _draw()
cls()

pal(cp)

--do animations
for z in all(a2) do
	if costatus(z)!="dead" then assert(coresume(z))
	else del(a2,z) end
end

--safe zone
for z in all(zs) do
	fillp(░)
	circfill(z.x,z.y,z.r,0x01)
--	circfill(z.x,z.y,z.r,0x0c)
	fillp()
	circfill(z.x,z.y,z.r-z.t,0)
	circ(z.x,z.y,z.r,1)
end

--flowers
for f in all(fs) do
	for l in all(f) do
			fillp(ˇ)
			circfill(l.x,l.y,l.r,11)
			fillp()
	end
	for l in all(f) do
			spr(20,l.x-4,l.y-4)
	end
end

--emitter
if state~="dead" then
	circ(64,64,inner.r,6)
	circ(64,64,1,8)
	if #lz==0 then circ(64,64,1,2) end
end

--homing bombs
for h in all(hs) do
--	if not h.enabled then pal(8,2) end
	if h.enabled then
	spr((flr(h.frametick%8)/2)+16,h.x-4,h.y-4)
	else
	spr(23,h.x-4,h.y-4)
	end
--	pal(cp)
end

--laser
for l in all(lz) do 	
	if rnd(1)>.1 then  
		line(64,64,l.x,l.y,8)
	else
		line(64,64,l.x,l.y,7)
--		circfill(l.x,l.y,rnd(3),8)
	end
end
--burn trail
for l in all(lz) do
	for i=1,5 do
		local a=l.a+.0025*i
		local f=8
--		if i>3 then f=2 end
		circfill(64+cos(a)*63,64+sin(a)*63,.75,f)
	--	pset(64+cos(a)*63,64+sin(a)*63,f)
	end
end

--player
if p.enabled then
	local m={x=p.x+cos(p.a)*2,y=p.y+sin(p.a)*2}
	local prow=.075
	local len=6
	local aft=len-2
	if p.thrusting then
		line(m.x-cos(p.a-prow)*aft,
							m.y-sin(p.a-prow)*aft,
							m.x-cos(p.a)*(aft+1),
							m.y-sin(p.a)*(aft+1),12)
		line(m.x-cos(p.a+prow)*aft,
							m.y-sin(p.a+prow)*aft,
							m.x-cos(p.a)*(aft+1),
							m.y-sin(p.a)*(aft+1),12)
	end
	line(m.x,m.y,m.x-cos(p.a-prow)*len,m.y-sin(p.a-prow)*len,7)
	line(m.x,m.y,m.x-cos(p.a+prow)*len,m.y-sin(p.a+prow)*len,7)
--circfill(m.x-cos(p.a)*2,m.y-sin(p.a)*2,1,7)
	if p.gunfail then
		circ(m.x,m.y,2,12)
		p.gunfail=false
	end
end

-- roids
for v in all(rs) do
--	fillp(⧗)
--	circfill(v.x,v.y,v.r,9)
--	fillp()
	circ(v.x,v.y,v.r,9)
	spr(2,v.x-4,v.y-4)
	local a=atan2(v.dx,v.dy)-.5
	local x=v.x+cos(a)*v.r
	local y=v.y+sin(a)*v.r
	local m=dist(0,0,v.dx,v.dy)*3
	line(x,y,x+cos(a)*m,y+sin(a)*m)
end

--bullet
if b.enabled then
	circ(b.x,b.y,1,12)
end

if w.enabled then
	circfill(64,64,w.r,0)
	circ(64,64,w.r,6)
end

if state=="dead" then
	local msg=""..extralives.." mulligans left\nthis sector"
	if extralives<0 then msg="gameover" end
	print(msg,64,64,7)
end


pal()

--hop countdown
local f=p.charge<p.fullcharge and 1 or 12
rect(105,3,126,9,f)
local pct=min(p.charge/p.fullcharge,1)
--if pct>1 then pct=1 end
rectfill(105,3,105+(126-105)*pct,9,f)
print("tele",106,4,7)

--gun countdown
local x,x2,y,y2=110,126,11,17
local f=p.gun<p.gunfull and 3 or 11
rect(x,y,x2,y2,f)
local pct=min(p.gun/p.gunfull,1)
rectfill(x,y,x+(x2-x)*pct,y2,f)
print("gun",x+2,y+1,7)

print("sector "..lvl,0,0,7)
for i=1,extralives do
	spr(22,i*6-6,10)
end

if w.enabled then
	circfill(64,64,w.r,0)
	circ(64,64,w.r,6)
else 
	circ(64,64,63,6)
end

--for i=1,1000 do
----	local x,y=rnd(127),rnd(127)
--	local d,a=rnd(64),rnd()
--	local x,y=63+cos(a)*d,63+sin(a)*d
--	local c=pget(x,y)
--	pset(x+rnd(2),y+rnd(2),c)
--end

--print(stat(1),0,120,7)

--score
--for k,v in pairs(passes) do
--	local sprite=11
--	if v then sprite=10	end
--	spr(sprite,scoreboxes[k][1],scoreboxes[k][2])
--end

end

-->8
--levels
lvls={
--	{flowers=1,bomb=true},
	{roids=4,lasers=1},
	{roids=6,lasers=1,safezone=true},
	{roids=4,lasers=1,flowers=3},
	{roids=6,bomb=true},
	{roids=4,flowers=3,bomb=true},
	{roids=3,flowers=2,bomb=true,lasers=1,safezone=true},
	{roids=5,lasers=2},
	{roids=7,lasers=2,safezone=true},
}

function wipe()
	local start=tick
	w.enabled=true
	while tick-start<30 do
		local pct=(tick-start)/30
		pct=easeoutexpo(pct)
		w.r=63*pct
		yield()
	end
	lz={}	zs={} hs={} rs={} fs={} b.enabled=false
	w.enabled=false
	lvl+=1
	add(as,cocreate(spawn))
end

function spawn()
	state="setup"
	i=10 c=15 p.x=64 p.y=32 p.dx=0 p.dy=0 p.charge=0 p.a=0 p.gun=0
	--player entering animation
	p.enabled=true
	local enteranim=cocreate(penter)
	coresume(enteranim,p.x,p.y,c)
	add(a2,enteranim)
	while c>0 do c-=1 yield() end
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
				add(rs,r)
				sfx(6)
				if #rs==num then break end
			end
			if unit=="safezone" then
				local z = {a=0,r=32,x=0,y=0,t=32,shrinking=false,speed=.25}
				z.a=rnd(1)
				z.x=64+cos(z.a)*63
				z.y=64+sin(z.a)*63
				add(zs,z)
				sfx(10)
				break
			end
			if unit=="lasers" then
				local a=(1/num)*#lz+.1
				add(lz,{a=a,x=64+cos(a)*63,y=64+sin(a)*63,speed=.005})
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
				r.growcount=0
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
	lz={}	zs={} hs={} rs={} fs={} b.enabled=false
	start=tick
	state="dead"
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
	state="setup"
	add(as,cocreate(spawn))
end

--player enter
function penter(x,y,duration)
	local start=tick
	local t=0
	local dur=duration/2
	while t<1 do
		t=(tick-start)/dur
		t=easeoutexpo(t)
		line(x,y,x+30*t,y)
		line(x,y,x-30*t,y)
		line(x,y,x,y+30*t)
		line(x,y,x,y-30*t)
		circfill(x,y,t*6,7)
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

--player death particles
function deathparticles(cause)
	local lines=p:lines()
	
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
		
		if i>0 then
			camera(rnd(4)-2,rnd(4)-2)
		else
			camera()
		end
		color(7)
		for l in all(lines) do
			l.midx+=l.dx 
			l.midy+=l.dy 
			l.r+=l.dr
			line(l.midx-cos(l.r)*4,
								l.midy-sin(l.r)*4,
								l.midx+cos(l.r)*4,
								l.midy+sin(l.r)*4)
		end
		for z in all(parts) do
			z.x+=z.dx z.y+=z.dy
			pset(z.x,z.y)
		end		
		pal(cp)
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

--what array elements satisfy predicate function
function filter(f,t)
	local r={}
	for _,v in ipairs(t) do
		if f(v) then add(r,v) end
	end
	return r
end

--do all array elements satisfy predicate function
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

--get random angle that is not within margin of given angle
function aim_away(ang,margin)
	local margin=margin or .25
	return rnd(1-margin)+ang+margin/2
end

function rndr(low,high)
	return low+rnd(high-low)
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
__gfx__
00000000006dd600000000000000000000000000002002000020020000000000000000000000000066666666666666666666666600e000000000e00000000000
0000000006666660000000000e0000e00e0000e0020220200202202000200200002002000020020060000bb6600008866000000600ee00000000ee0000000000
0070070066dddd660000000000eeee0000eeee0020222202202222020200002002022020020220206000bbb6600888066000000600eeeeee0eeeee0000000000
00077000d6d88d6d0008000000e00e0000e88e0002200220022882200002200000200200002882006b0bb006608880066000000600e00ee0eee00e0000000000
00077000d6d88d6d0080800000e00e0000e88e00022002200228822000022000002002000028820060bb000668800006600000060ee00e0000e00eee00000000
0070070066dddd660008000000eeee0000eeee002022220220222202020000200202202002022020666666666666666666666666eeeeee0000eeeee000000000
0000000006666660000000000e0000e00e0000e002022020020220200020020000200200002002000000000000000000000000000000ee0000ee000000000000
00000000006dd600000000000000000000000000002002000020020000000000000000000000000000000000000000000000000000000e00000e000000000000
0f00000000f00000000f00000000f0000008000000eee00000700000000000000000000000000000000000000000000000000000000000000000000000000000
00f0000f000f00000000f00000000f00008080000e00eee000700000ff0000ff0000000000000000000000000000000000000000000000000000000000000000
00fffff000ffff0f00ffff000fffff0008eee800e00000ee0777000000ffff000000000000000000000000000000000000000000000000000000000000000000
00f88f0000f88ff00ff88f0ff0f88f0080e8e080e000000e7707700000f22f000000000000000000000000000000000000000000000000000000000000000000
00f88f000ff88f00f0f88ff000f88f0f08eee800e00000ee7000700000f22f000000000000000000000000000000000000000000000000000000000000000000
0fffff00f0ffff0000ffff0000fffff0008080000e000ee00000000000ffff000000000000000000000000000000000000000000000000000000000000000000
f0000f000000f000000f000000f00000000800000ee0ee0000000000ff0000ff0000000000000000000000000000000000000000000000000000000000000000
000000f000000f000000f000000f000000000000000ee00000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555500088888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55050550880808800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55050550888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555550880008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555500088888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05050500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
85800000555b00005550000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
58500000b5b000005550000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
858000005b5000005550000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
000100003f5503f5503c5503a55037550375503755033550305502e550295502755024550245502255022550225501f5501d5501d5501d55018550185501655016550115500f5500f5500c5500a5500a55007550
000800000352000510075000750007500075000750007500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000316503165030650316503a70037700306502c6502d6502e650307003370033700276002c6502d6502c65030700276002d6502c650306503365000700007002a6502a650296500070024650226501f650
001400000c1200a12007120031200f1200c1200a120071200c1200a12007120031200f1200c1200a120071200c1200a12007120031200f1200c1200a120071200c1200a12007120031200f1200c1200a12007120
011400000a650006000060000600056500060000600006000a650006000060000600056500060000600006000a650006000060000600056500060000600006000a65005600036000060005650006000060000600
001400001145011450114501145011400114001345216452114001345016450164001145011450114501145000400274002740027400274000040000400004000040000400004000040000400004000040000400
011400000645014400114000000006450084500545000000064501440011400000000645008450054500000006450144001140000000064500845005450000000645014400114000000006450084500545000000
__music__
00 0e0f4344
00 0e0f4344
00 0e110f44

