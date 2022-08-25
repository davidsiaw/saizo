var pennies, Int >= 0
var nickels, Int >= 0
var quarters, Int >= 0
var dimes,    Int >= 0

totalvalue = pennies * 1 + nickels * 5 + dimes * 10 + quarters * 25

constraint totalvalue == 300

weight = pennies * 2.54 + nickels * 5 + dimes * 2.268 + quarters * 5.67

minimize weight
