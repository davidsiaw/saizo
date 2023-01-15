import Pkg;
Pkg.add("PackageCompiler");
Pkg.add("JuMP");
Pkg.add("Cbc");
Pkg.add("HiGHS")

using PackageCompiler;

create_sysimage(sysimage_path="/install/SysImage.so");

