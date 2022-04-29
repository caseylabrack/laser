pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- lasers
-- casey labrack

p = {x=50,y=30,dx=0,dy=0,a=0,t=1,rt=.05,r=3,lb=0}
l = {a=0,x=0,y=0,speed=.005}
b = {x=0,y=0,a=0,r=1,speed=5,enabled=false}
z = {a=0,r=30,x=0,y=0,shrinking=false,speed=1}
inner = {x=64,y=64,r=6}
maxrspeed=1
minrspeed=.1
lvl=1
log = ""
isgameover=false
rs={}

function _init()
--init zone
z.a=rnd(1)
z.x=cos(a)*63
z.y=sin(a)*63
z.r=30

--init roids
	local a,d,x,y,dx,dy
	for i=1,7 do
		flag=true
		while flag do
			a=rnd(1)
			d=6+rnd(63-6)
			x=64+cos(a)*d
			y=64+sin(a)*d
--			dx=rnd(2)-1
--			dy=rnd(2)-1
			
			if dist(x,y,p.x,p.y)<20 then
				flag=true else flag=false
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
end

function _update()
-- laser move
l.a-= l.speed
l.x = 64 + cos(l.a) * 63
l.y = 64 + sin(l.a) * 63

-- safe zone
if z.shrinking then
--if touching(p,z) then
	z.r-=.25--z.speed
	if z.r<2 then
		z.a=rnd(1)
		z.x=64+cos(z.a)*63
		z.y=64+sin(z.a)*63
		z.r=30
		z.shrinking=false
	end
end
if touching(p,z) then z.shrinking=true end

--	player move
if btn(➡️) then p.a=p.a-p.rt end
if btn(⬅️) then p.a=p.a+p.rt end
if btn(⬆️) and p.lb+2<t() then 
--	p.x+=cos(p.a)*8
--	p.y+=sin(p.a)*8
	p.dx+=cos(p.a)*3
	p.dy+=sin(p.a)*3
	p.lb=t()
end
if btn(⬇️) then	p.dx=0 p.dy=0 end
if btn(🅾️) then 
	p.dx=p.dx+cos(p.a)*.1
	p.dy=p.dy+sin(p.a)*.1
end
if btn(❎) and not b.enabled then
	b.enabled=true
	b.x=p.x b.y=p.y b.a=p.a
end
p.x=p.x+p.dx
p.y=p.y+p.dy
p.dx=p.dx*.96
p.dy=p.dy*.96

local ang=atan2(p.x-64,p.y-64)

-- player vs outside wall
if dist(p.x,p.y,64,64) > 63 then
	p.x=64+cos(ang)*63 
	p.y=64+sin(ang)*63
end

-- player vs inside wall
if dist(p.x,p.y,64,64) < 8 then
	p.x=64+cos(ang)*8 
	p.y=64+sin(ang)*8
end

-- player vs. obstacles
for _,v in pairs(rs) do
	if v.x>-5 and v.x<134 and v.y>-5 and v.y<134 then
		if dist(p.x,p.y,v.x,v.y)<p.r+v.r then
			gameover=true
			_update=function() end
		end
	end
end

--laser/player collision
local d=dist(p.x,p.y,64,64)
--if dist(p.x,p.y,hx,hy) < 3 then
if touching(p,{x=64+cos(l.a)*d,y=64+sin(l.a)*d,r=0}) then
	if not touching(p,z) then
		gameover=true
		_update=function() end
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
	b.x+=cos(b.a)*b.speed
	b.y+=sin(b.a)*b.speed
end
if dist(b.x,b.y,64,64)>63 then b.enabled=false end
if touching(b,inner) then b.enabled=false end
for v in all(rs) do
--	if b.enabled and dist(b.x,b.y,v.x,v.y)<b.r+v.r then
	if b.enabled and touching(b,v) then
		v.r-=1
		b.enabled=false
		if v.r<2 then	del(rs,v) end
	end	
end
end

function _draw()
cls()

--safe zone
fillp(░)
circfill(z.x,z.y,z.r,0x08)
fillp()
circ(z.x,z.y,z.r,8)

line(64,64,l.x,l.y,8) --laser
circfill(64,64,4,8) --inner
circ(64,64,4,6) --inner2
circ(64,64,63,6) --outer
--player
circfill(p.x,p.y,p.r,14) 
line(p.x,p.y,p.x+cos(p.a)*6,p.y+sin(p.a)*6)

-- roids
for v in all(rs) do
	circfill(v.x,v.y,v.r,9)
	local a=atan2(v.dx,v.dy)-.5
	local x=v.x+cos(a)*v.r
	local y=v.y+sin(a)*v.r
	local m=dist(0,0,v.dx,v.dy)*3
	line(x,y,x+cos(a)*m,y+sin(a)*m)
end

if b.enabled then
	circfill(b.x,b.y,b.r,12)
end

print(log)
print(lvl,63,63,10)

if gameover then
--	local l=print("gameover",-10,0)
	print("gameover",128-30,0)
end

end

-->8
--cos1 = cos function cos(angle) return cos1(angle/(3.1415*2)) end
--sin1 = sin function sin(angle) return -sin1(angle/(3.1415*2)) end

function dist(x1,y1,x2,y2)
	return sqrt((x1-x2) * (x1-x2)+(y1-y2)*(y1-y2))
end

function distt(t1,t2)
	return sqrt((t1.x-t2.x) * (t1.x-t2.x)+(t1.y-t2.y)*(t1.y-t2.y))
end

function touching(a,b)
	return distt(a,b)<a.r+b.r
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
