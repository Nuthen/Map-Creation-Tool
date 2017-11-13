-- where triangle is a list {x1,y1, x2,y2, x3,y3}
-- and   point    is a list {x, y}
function isPointInTriangle(triangle, point)
    local p0x,p0y, p1x,p1y, p2x,p2y = unpack(triangle)
    local px,py = unpack(point)

    local area = 0.5 *(-p1y*p2x + p0y*(-p1x + p2x) + p0x*(p1y - p2y) + p1x*p2y)

    local s = 1/(2*area)*(p0y*p2x - p0x*p2y + (p2y - p0y)*px + (p0x - p2x)*py)
    local t = 1/(2*area)*(p0x*p1y - p0y*p1x + (p0y - p1y)*px + (p1x - p0x)*py)

    return s > 0 and t > 0 and 1-s-t > 0
end
