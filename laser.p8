pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- lasers
-- casey labrack

p = {x=80,y=30,dx=0,dy=0,
					a=.75,t=.25,rt=.05,r=3,
					friction=.92,hop=25,charge=0,fullcharge=90}
lz= {} --lasers
zs= {} --safe zones
hs= {} --homing bombs
b = {x=0,y=0,a=0,r=1,speed=5,enabled=false}
inner = {x=64,y=64,r=6}
outer = {x=64,y=64,r=63}
maxrspeed=2
minrspeed=.5
lvl=2
log = ""
isgameover=false
rs={}
tick=0

function _init()
lvls[lvl]()
end

function _update()
tick+=1

-- laser move
for l in all(lz) do
	l.a-= l.speed
	l.x = 64 + cos(l.a) * 63
	l.y = 64 + sin(l.a) * 63
end

-- safe zones
for z in all(zs) do
	if z.shrinking then
	--if touching(p,z) then
		z.t-=.25--z.speed
		if z.t<2 then
			z.a=rnd(1)
			z.x=64+cos(z.a)*63
			z.y=64+sin(z.a)*63
			z.t=32
			z.shrinking=false
		end
	end
	if touching(p,z) then z.shrinking=true end
end

--homing bomb move
for h in all(hs) do
	local a=atan2(p.x-h.x,p.y-h.y)
	h.dx+=cos(a)*h.t
	h.dy+=sin(a)*h.t
	h.dx*=.97
	h.dy*=.97
	h.x+=h.dx
	h.y+=h.dy
	local a2=atan2(h.x-64,h.y-64)
	if touching(h,inner) then
		h.x=inner.x+cos(a2)*(inner.r+1)
		h.y=inner.y+sin(a2)*(inner.r+1)
	end
	if dist(h.x,h.y,64,64)>63 then
		h.x=64+cos(a2)*63
		h.y=64+sin(a2)*63	
	end
end

--	player move
p.charge+=1
if btn(➡️) then p.a=p.a-p.rt end
if btn(⬅️) then p.a=p.a+p.rt end
if btn(⬆️) and p.charge>p.fullcharge then 
	p.x+=cos(p.a)*p.hop
	p.y+=sin(p.a)*p.hop
--	p.dx+=cos(p.a)*6
--	p.dy+=sin(p.a)*6
--	p.lb=t()
	p.charge=0
end
if btn(⬇️) then	p.dx=0 p.dy=0 end
if btn(🅾️) then 
	p.dx+=cos(p.a)*p.t
	p.dy+=sin(p.a)*p.t
end
if btn(❎) and not b.enabled then
	b.enabled=true
	b.x=p.x b.y=p.y b.a=p.a
end
p.x=p.x+p.dx
p.y=p.y+p.dy
p.dx*=p.friction
p.dy*=p.friction

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

-- player vs. obstacles
for v in all(rs) do
	if touching(p,v) then
		gameover=true
		_update=function() end
	end
end

--player vs. homing bombs
for h in all(hs) do
	if touching(p,h) then
		gameover=true
		_update=function() end
	end
end

--laser/player collision
local d=dist(p.x,p.y,64,64)
local vulnerable=true
for z in all(zs) do
	if touching(p,z) then vulnerable=false break end
end
if vulnerable then
	for l in all(lz) do
		if touching(p,{x=64+cos(l.a)*d,y=64+sin(l.a)*d,r=0}) then
			gameover=true
			_update=function() end
		end
	end
end

--bouncing around
for v in all(rs) do
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
end

--bullet
if b.enabled then
	local x1=b.x 
	local y1=b.y
	for i=1,10 do
		b.x=x1+cos(b.a)*b.speed*i/10
		b.y=y1+sin(b.a)*b.speed*i/10
		for v in all(rs) do
			if touching(b,v) then
				b.enabled=false
				v.r-=1
				if v.r<2 then	del(rs,v) end
				goto donebullet
			end
		end
		for h in all(hs) do
			if touching(h,b) then
				b.enabled=false
				del(hs,h)
				goto donebullet
			end
		end
		if touching(inner,b) then
			b.enabled=false
			goto donebullet
		end
		if not touching(outer,b) then
			b.enabled=false
			goto donebullet
		end
	end
end
::donebullet::

--level win
if #rs==0 and #hs==0 then 
	lvl+=1
	lz={}
	zs={}
	hs={}
	p.x=64 p.y=30
	if lvls[lvl] then lvls[lvl]() end
end

end

function _draw()
cls()

circ(64,64,63,6) -- outer

--emitter
circ(64,64,inner.r,6)
circ(64,64,1,8)
if #lz==0 then circ(64,64,1,2) end

--homing bombs
for h in all(hs) do
	spr(tick%2+3,h.x-4,h.y-4)
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

--laser
for l in all(lz) do 	
	if rnd(1)>.33 then  
	line(64,64,l.x,l.y,8)
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
--circfill(p.x,p.y,p.r,14) 
--line(p.x,p.y,p.x+cos(p.a)*6,p.y+sin(p.a)*6)
local m={x=p.x+cos(p.a)*2,y=p.y+sin(p.a)*2}
local prow=.075
local len=6
local aft=len-2
if btn(🅾️) then
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
	local dx=cos(b.a+5)
	local dy=sin(b.a+5)
	line(b.x+dx*2,b.y+dy*2,b.x+dx*4,b.y+dy*4,1)
	line(b.x,b.y,b.x+dx*2,b.y+dy*2,12)
end

--hop countdown
local f=12
--local rekt={x=105,y=}
if (p.charge<p.fullcharge) f=1
rect(105,3,126,9,f)
local pct=p.charge/p.fullcharge
if pct>1 then pct=1 end
rectfill(105,3,105+(126-105)*pct,9,f)
print("tele",106,4,7)

print(log)
print(lvl,0,0,10)

--if gameover then
----	local l=print("gameover",-10,0)
--	print("gameover",128-30,0)
--end

end

-->8
--utils

function dist(x1,y1,x2,y2)
	return sqrt((x1-x2) * (x1-x2)+(y1-y2)*(y1-y2))
end

function distt(t1,t2)
	return sqrt((t1.x-t2.x) * (t1.x-t2.x)+(t1.y-t2.y)*(t1.y-t2.y))
end

function touching(a,b)
	return distt(a,b)<a.r+b.r
end
-->8
--levels
lvls={}
lvls[1]=function() 
	for i=1,4 do spawnroid() end
	add(lz,{a=0,x=0,y=0,speed=.005})
end
lvls[2]=function()
	for i=1,7 do spawnroid() end
	spawnzone()
	add(lz,{a=0,x=0,y=0,speed=.005})
end
lvls[3]=function()
	for i=1,4 do spawnroid() end
	add(lz,{a=.5,x=0,y=0,speed=.005})
	add(lz,{a=0,x=0,y=0,speed=.005})
end
lvls[4]=function()
	for i=1,4 do spawnroid() end
	add(lz,{a=0,x=0,y=0,speed=.005})
end
lvls[5]=function()
	local h={x=80,y=64+rnd(64),r=6,dx=0,dy=0,t=.1}
	add(hs,h)
	add(lz,{a=.5,x=0,y=0,speed=.005})
end
lvls[6]=function()
	local h={x=80,y=64+rnd(64),r=6,dx=0,dy=0,t=.1}
	for i=1,4 do spawnroid() end
	add(hs,h)
	add(lz,{a=.5,x=0,y=0,speed=.005})
end

function spawnzone()
	local z = {a=0,r=32,x=0,y=0,t=32,shrinking=false,speed=1}
	z.a=rnd(1)
	z.x=64+cos(z.a)*63
	z.y=64+sin(z.a)*63
	add(zs,z)
end

function spawnroid()
local a,d,x,y,dx,dy
valid=false
while valid==false do
	a=rnd(1)
	d=6+rnd(63-6)
	x=64+cos(a)*d
	y=64+sin(a)*d
	
	if dist(x,y,p.x,p.y)>40 then 
		valid=true
	end		
end
	
	local atop=atan2(x-p.x,y-p.y)
--		local atop=atan2(p.x-x,p.y-y)
	dx=cos(atop)*(rnd(maxrspeed-minrspeed)+minrspeed)
	dy=sin(atop)*(rnd(maxrspeed-minrspeed)+minrspeed)
--		if atop-atan2(dx,dy)<.2 then
--			a+=.25+rnd(.5)
--		end
	
	add(rs,{
		x=64+cos(a)*d,
		y=64+sin(a)*d,
		r=3+rnd(8-3),
		dx=dx,
		dy=dy
--			dx=rnd(2)-1,
--			dy=rnd(2)-1
	})
end
__gfx__
00000000006dd6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000006666660000000000e0000e00e0000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070066dddd660000000000eeee0000eeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000d6d88d6d0008000000e00e0000e88e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000d6d88d6d0080800000e00e0000e88e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070066dddd660008000000eeee0000eeee000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000006666660000000000e0000e00e0000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006dd6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
