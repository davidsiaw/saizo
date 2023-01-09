item penny do
  value 1
  weight 2.54
end

item nickel do
  value 5
  weight 5
end

item dime do
  value 10
  weight 2.268
end

item quarter do
  value 25
  weight 5.67
end

pouch bag, penny, nickel, dime, quarter

constraint bag.value_sum >= 1232

minimize bag.weight_sum

