pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
d = 1

function _draw()
		d *= 1.1
  cls()
  poke(0x5f34,0x2)
	 for z=100,1,-1 do
    local sx = cos(z+t()/4) * 50
    local sy = sin(z+t()/4) * 50
    circfill(64+sx/z,64+sy/z,64/z*d, 0 | 0x1800)
    circ(64+sx/z,64+sy/z,64/z*d, 5 | 0x1800)
  end
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000