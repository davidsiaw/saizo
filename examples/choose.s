item gp1 do
  gt 0
  pe 0
  gp 1
  cost 100
end

item gt1 do
  gt 11
  pe 0
  gp 0
  cost 1000
end

choice a, gp1, gt1

pouch equip1, a, a

totalgt = equip1.gt_sum
totalgp = equip1.gp_sum
totalcost = equip1.cost_sum

maximize totalgt + totalgp

show 'cost', totalcost