### A Pluto.jl notebook ###
# v0.12.4

using Markdown
using InteractiveUtils

# ╔═╡ 37374272-0d9a-11eb-1eb1-65c867f1d867
begin
	using Pkg
	Pkg.activate(".")
end

# ╔═╡ 4569bd20-0d9a-11eb-30c0-d98f9f6b3306
begin
	using CSV
	using DataFrames
	using PlutoUI
	using Dates
	using Plots
end

# ╔═╡ 7e3846de-0d98-11eb-16ca-b3b6fd290a22
md"""
# Analysis of Glycaemic trends
"""

# ╔═╡ f2eecdea-0d98-11eb-2b2d-fb07509edcae
pwd()

# ╔═╡ 2d7461a4-0d9a-11eb-1ce3-73e77884798e
Base.load_path()

# ╔═╡ 5dcea10c-0d9a-11eb-2f9f-434a79f73daa
data_entries = "data/" .* readdir("data/")

# ╔═╡ 7dffdc3e-0fd9-11eb-1110-e9d5e0afcea7
data = CSV.read(data_entries[1]);

# ╔═╡ 4178c9d2-0fda-11eb-3a43-376139cd6f28
names(data)

# ╔═╡ 6b74c526-0fdd-11eb-0e44-b922ac9e901f
begin
	basal = data["Basal Rate (U/h)"]
	glycaemia = data["Sensor Glucose (mg/dL)"]
end

# ╔═╡ b8dca518-0fda-11eb-1e7e-edc7d359bf5e
date_strings = data["DateTime"];

# ╔═╡ d64772d4-0fda-11eb-171a-a902e70284c7
format = Dates.DateFormat("Y-m-d H:M:S");

# ╔═╡ 8f517d88-0fdb-11eb-0b8a-5b3d661a8dad
dates = parse.(DateTime, date_strings, format);

# ╔═╡ 853d003e-0fda-11eb-068e-a7f659325b4a
plot(dates, glycaemia)

# ╔═╡ 3a7572dc-0fdc-11eb-3a1f-e3dfaeb46838
plot(dates, basal)

# ╔═╡ 3b8d4802-0fdc-11eb-2df2-0d877ec3ab96


# ╔═╡ Cell order:
# ╠═7e3846de-0d98-11eb-16ca-b3b6fd290a22
# ╠═f2eecdea-0d98-11eb-2b2d-fb07509edcae
# ╠═2d7461a4-0d9a-11eb-1ce3-73e77884798e
# ╠═37374272-0d9a-11eb-1eb1-65c867f1d867
# ╠═4569bd20-0d9a-11eb-30c0-d98f9f6b3306
# ╠═5dcea10c-0d9a-11eb-2f9f-434a79f73daa
# ╠═7dffdc3e-0fd9-11eb-1110-e9d5e0afcea7
# ╠═4178c9d2-0fda-11eb-3a43-376139cd6f28
# ╠═6b74c526-0fdd-11eb-0e44-b922ac9e901f
# ╠═b8dca518-0fda-11eb-1e7e-edc7d359bf5e
# ╠═d64772d4-0fda-11eb-171a-a902e70284c7
# ╠═8f517d88-0fdb-11eb-0b8a-5b3d661a8dad
# ╠═853d003e-0fda-11eb-068e-a7f659325b4a
# ╠═3a7572dc-0fdc-11eb-3a1f-e3dfaeb46838
# ╠═3b8d4802-0fdc-11eb-2df2-0d877ec3ab96
