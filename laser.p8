pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- lasers
-- casey labrack

p = {x=80,y=30,dx=0,dy=0,
					a=.75,t=.25,rt=.05,r=3,
					friction=.92,hop=25,charge=0,fullcharge=90,
					enabled=true,controllable=true,alive=true,
					thrusting=false}
ps= {} --player death particles
lz= {} --lasers
zs= {} --safe zones
hs= {} --homing bombs
as= {} --animations (coroutines)
b = {x=0,y=0,dx,dy,a=0,r=1,speed=5,enabled=false}
w = {enabled=false,start=0,duration=100,r=0}
inner = {x=64,y=64,r=6}
outer = {x=64,y=64,r=63}
maxrspeed=2
minrspeed=.5
lvl=5
lives=3
passes={}
log = ""
isgameover=false
rs={}
tick=0
lvlswitchtick=90
transitioning=false
scoreboxes={{0,0},{7,0},{14,0},{21,0}}

function _init()
lvls[lvl]()
--	local a=cocreate(lvls2[lvl])
--	add(as,a)
end

function _update()
tick+=1

-- do animations
for a in all(as) do
	if costatus(a)!="dead" then coresume(a)
	else del(as,a) end
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
	if h.enabled then
		local a=atan2(p.x-h.x,p.y-h.y)
		h.dx+=cos(a)*h.t
		h.dy+=sin(a)*h.t
		h.frametick+=1
	else 
		h.timer-=1
		if h.timer<0 then h.enabled=true end
		sfx(3)	
	end
	h.dx*=.97
	h.dy*=.97
	h.x+=h.dx
	h.y+=h.dy
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

--	player move
p.charge+=1
if p.controllable and p.alive then
	if btn(➡️) then p.a=p.a-p.rt end
	if btn(⬅️) then p.a=p.a+p.rt end
	if btn(⬆️) and p.charge>p.fullcharge then 
		p.x+=cos(p.a)*p.hop
		p.y+=sin(p.a)*p.hop
		p.charge=0
	end
	if btn(⬇️) then	p.dx=0 p.dy=0 end
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
		b.enabled=true
		b.x=p.x b.y=p.y b.a=p.a
		b.dx=cos(b.a)*b.speed b.dy=sin(b.a)*b.speed
	end
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
--		died()
		gameover=true
		_update=function() end
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
				p.enabled=false
				add(ps,{x1=p.x,y1=p.y,x2=p.x+3,y2=p.y+3})
					gameover=true
					_update=function() end
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
	for i=1,10 do
		b.x=x1+b.dx*i/10
		b.y=y1+b.dy*i/10
		for v in all(rs) do --roids
			if touching(b,v) then
				b.enabled=false
				v.r-=1
				if v.r<2 then	del(rs,v) end
				goto donebullet
			end
		end
		for h in all(hs) do --homing
			if touching(h,b) then
				b.enabled=false
				h.enabled=false
				h.timer=60
				h.dx+=b.dx/4 
				h.dy+=b.dy/4
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
if #rs==0 and not transitioning then
--	nxtlvl()	
	p.x=64 p.y=30

	lz={}
	zs={}
	hs={}
	add(passes,true)
	lvl+=1
	lvls[lvl]()
end
end

function nxtlvl()
	transitioning=true
	lz={}
	zs={}
	hs={}
	add(passes,true)
	p.controllable=false
	lvl+=1
	local a=cocreate(lvls2[lvl])
	add(as,a)
end

function clearlvl()
	p.x=64 p.y=30
	lz={}
	zs={}
	hs={}
	rs={}
end

function died()
	clearlvl()
	loadlvl()
end

function beatlvl()
	clearlvl()
	lvl+=1
	loadlvl()
end

function loadlvl()

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
	if not h.enabled then pal(8,2) end
	spr((flr(h.frametick%8)/2)+16,h.x-4,h.y-4)
	pal()
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
--circfill(p.x,p.y,p.r,14) 
--line(p.x,p.y,p.x+cos(p.a)*6,p.y+sin(p.a)*6)
if p.enabled then
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
else 
	for p2 in all(ps) do
		line(p2.x1,p2.y1,p2.x2,p2.y2,7)
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
	local dx=cos(b.a+5)
	local dy=sin(b.a+5)
	line(b.x+dx*2,b.y+dy*2,b.x+dx*4,b.y+dy*4,1)
	line(b.x,b.y,b.x+dx*2,b.y+dy*2,12)
end

if w.enabled then
	circfill(64,64,w.r,0)
	circ(64,64,w.r,6)
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

print("sector "..lvl,0,0,1)

--score
--for k,v in pairs(passes) do
--	local sprite=11
--	if v then sprite=10	end
--	spr(sprite,scoreboxes[k][1],scoreboxes[k][2])
--end


print(log)
--print(lvl,0,0,10)

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
--	for i=1,4 do spawnroid() end
	spawnroid()
	add(lz,{a=0,x=0,y=0,speed=.005})
end
lvls[2]=function()
--	for i=1,7 do spawnroid() end
	spawnroid()
	spawnzone()
	add(lz,{a=0,x=0,y=0,speed=.005})
end
lvls[3]=function()
--	for i=1,4 do spawnroid() end
	spawnroid()
	add(lz,{a=.5,x=0,y=0,speed=.005})
	add(lz,{a=0,x=0,y=0,speed=.005})
end
lvls[4]=function()
	for i=1,4 do spawnroid() end
	add(lz,{a=0,x=0,y=0,speed=.005})
end
lvls[5]=function()
	spawnbomb()
	for i=1,4 do spawnroid() end
	add(lz,{a=.5,x=0,y=0,speed=.005})
end
lvls[6]=function()
	spawnbomb()
	for i=1,7 do spawnroid() end
	add(hs,h)
	add(lz,{a=.5,x=0,y=0,speed=.005})
end

function spawnzone()
	local z = {a=0,r=32,x=0,y=0,t=32,shrinking=false,speed=.25}
	z.a=rnd(1)
	z.x=64+cos(z.a)*63
	z.y=64+sin(z.a)*63
	add(zs,z)
end

function spawnbomb()
	add(hs,{x=80,y=64+rnd(64),
	r=3,dx=0,dy=0,t=.1,
	enabled=true,timer=0,
	frametick=0}) 
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
		dy=dy,
		enabled=true
--			dx=rnd(2)-1,
--			dy=rnd(2)-1
	})
--	sfx(1)
end
-->8
--modes
function startlvl()

end

function nextlvl(start)
	w.enabled=true
	printh(start)
	local t=0
	while t<=1 do
		t=(tick-start)/30
		w.r=inner.r+(outer.r-inner.r)*t
		printh("t is"..t)
		yield()
	end
	w.enabled=false
	lvl+=1
	lz={}
	zs={}
	hs={}
	p.x=64 p.y=30
	if lvls[lvl] then lvls[lvl]() end
	add(passes,true)
	transitioning=false
	return
end

lvls2={}
lvls2[1]=function() 
	local tickcount=0
	local roids=0
	while roids<4 do
		if tickcount<=0 then
			spawnroid()
			tickcount=30
			roids+=1
		end
		tickcount-=1
		yield()
	end
	while tickcount>0 do tickcount-=1 yield() end
	add(lz,{a=0,x=0,y=0,speed=.005})
	for r in all(rs) do r.enabled=true end
	p.controllable=true
	return
end
lvls2[2]=function() 
	local tickcount=0
	local roids=0
	while roids<7 do
		if tickcount<=0 then
			spawnroid()
			tickcount=30
			roids+=1
		end
		tickcount-=1
		yield()
	end
	add(lz,{a=0,x=0,y=0,speed=.005})
	for r in all(rs) do r.enabled=true end
	p.controllable=true
	return
end

__gfx__
00000000006dd600000000000000000000000000002002000020020000000000000000000000000066666666666666666666666600e000000000e00000000000
0000000006666660000000000e0000e00e0000e0020220200202202000200200002002000020020060000bb6600008866000000600ee00000000ee0000000000
0070070066dddd660000000000eeee0000eeee0020222202202222020200002002022020020220206000bbb6600888066000000600eeeeee0eeeee0000000000
00077000d6d88d6d0008000000e00e0000e88e0002200220022882200002200000200200002882006b0bb006608880066000000600e00ee0eee00e0000000000
00077000d6d88d6d0080800000e00e0000e88e00022002200228822000022000002002000028820060bb000668800006600000060ee00e0000e00eee00000000
0070070066dddd660008000000eeee0000eeee002022220220222202020000200202202002022020666666666666666666666666eeeeee0000eeeee000000000
0000000006666660000000000e0000e00e0000e002022020020220200020020000200200002002000000000000000000000000000000ee0000ee000000000000
00000000006dd600000000000000000000000000002002000020020000000000000000000000000000000000000000000000000000000e00000e000000000000
00f00000000f00000000f00000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f00000000f00000000f00000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00ffffff00ffff0000ffff00ffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f88f0000f88ffffff88f0000f88f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f88f00fff88f0000f88fff00f88f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffffff0000ffff0000ffff0000ffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000f000000f000000f000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000f000000f000000f000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
000e000702770027700477004770027700b7700b7700f70005700047002e7002e7000370003700037000370003700037000370003700037000370003700077000770007700077000770000700007000070000700
