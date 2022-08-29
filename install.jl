import Pkg;
Pkg.add("PackageCompiler");
Pkg.add("JuMP")
Pkg.add("Cbc");

using PackageCompiler;
using JuMP;
using Cbc;
m = Model(Cbc.Optimizer);
create_sysimage(sysimage_path="SysImage.so")
