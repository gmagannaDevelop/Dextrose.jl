### A Pluto.jl notebook ###
# v0.12.4

using Markdown
using InteractiveUtils

# ╔═╡ 37374272-0d9a-11eb-1eb1-65c867f1d867
begin
	using Pkg
	Pkg.activate("..")
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

# ╔═╡ d05462fc-1076-11eb-0421-310c1326ed21
data_dir = "../data/"

# ╔═╡ 5dcea10c-0d9a-11eb-2f9f-434a79f73daa
data_entries = data_dir .* readdir(data_dir)

# ╔═╡ 7dffdc3e-0fd9-11eb-1110-e9d5e0afcea7
data = CSV.read(data_entries[1]);

# ╔═╡ 4178c9d2-0fda-11eb-3a43-376139cd6f28
names(data)

# ╔═╡ 3f95c168-105e-11eb-2c3d-f3f9dbbbcd9a
md"""
## Extract useful information 
"""

# ╔═╡ 6b74c526-0fdd-11eb-0e44-b922ac9e901f
begin
	basal = data["Basal Rate (U/h)"]
	glycaemia = data["Sensor Glucose (mg/dL)"]
	sensitivity = data["BWZ Insulin Sensitivity (mg/dL/U)"]
	ratio =  data["BWZ Carb Ratio (g/U)"]
	carb_insulin = data["BWZ Food Estimate (U)"]
	correction_insulin_estimate = data["BWZ Correction Estimate (U)"]
	active_insulin = data["BWZ Active Insulin (U)"]
	correction_insulin_total = correction_insulin_estimate .+ active_insulin
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
scatter(dates, ratio)

# ╔═╡ b7d4a72a-105e-11eb-3582-af78a865e0b4
scatter(dates, sensitivity)

# ╔═╡ fe403ff8-107c-11eb-3cb2-4fcee90989ce
collect(correction_insulin_total)

# ╔═╡ b57ee2dc-1078-11eb-180a-63f457b83147
# Goed :
# correction_idx = findall(!ismissing, correction_insulin_estimate)

# ╔═╡ 2aa7f6e6-1080-11eb-05a3-99a85b4bc22d
# Better : 
correction_idx = findall(x -> !ismissing(x) && x != 0.0, correction_insulin_estimate)

# ╔═╡ e36baec8-107d-11eb-28bf-0f019441c2b7
true_corrections = correction_insulin_estimate[correction_idx]

# ╔═╡ aa67a4bc-1080-11eb-3923-0b6287c32562
count(ismissing, correction_insulin_estimate)

# ╔═╡ 18291724-1081-11eb-044a-af3ebe5a8a37
count(ismissing, true_corrections)

# ╔═╡ 4375a384-1081-11eb-060a-c9ec078121c0
correction_timestamps = dates[correction_idx]

# ╔═╡ 956a5db0-1081-11eb-3bf3-25df114db076
foo = dates[1] + Dates.Minute(1)

# ╔═╡ 31026d8c-1083-11eb-3df8-79ba8e6fa761


# ╔═╡ 0a0fc124-1083-11eb-2fc5-076188d12ed9
los_rangos = [
	estampa:Dates.Minute(1):estampa + Dates.Hour(3) for estampa in correction_timestamps
]

# ╔═╡ 5e22132a-1086-11eb-11a9-abde1f5e2112
collect(los_rangos[1])

# ╔═╡ 75395cac-1087-11eb-3b5a-c3123503b6cd
les_intervals = [
	val:1:val+180 for val in correction_idx
]

# ╔═╡ ce5298a8-1087-11eb-0c3b-ada77ce848c6
glycaemia[les_intervals[3]]

# ╔═╡ 5147ed40-1087-11eb-00ec-6d3693cb2012
findfirst(correction_timestamps)

# ╔═╡ 7b0706b8-1085-11eb-23c9-419e48bacc00
correction_timestamps[1] .== dates

# ╔═╡ 51d7cd2e-1083-11eb-2e9b-a1701faa993d
for i in eachindex(los_indices[1])
	println(i)
end

# ╔═╡ Cell order:
# ╟─7e3846de-0d98-11eb-16ca-b3b6fd290a22
# ╠═f2eecdea-0d98-11eb-2b2d-fb07509edcae
# ╠═2d7461a4-0d9a-11eb-1ce3-73e77884798e
# ╠═37374272-0d9a-11eb-1eb1-65c867f1d867
# ╠═4569bd20-0d9a-11eb-30c0-d98f9f6b3306
# ╠═d05462fc-1076-11eb-0421-310c1326ed21
# ╠═5dcea10c-0d9a-11eb-2f9f-434a79f73daa
# ╠═7dffdc3e-0fd9-11eb-1110-e9d5e0afcea7
# ╠═4178c9d2-0fda-11eb-3a43-376139cd6f28
# ╟─3f95c168-105e-11eb-2c3d-f3f9dbbbcd9a
# ╠═6b74c526-0fdd-11eb-0e44-b922ac9e901f
# ╠═b8dca518-0fda-11eb-1e7e-edc7d359bf5e
# ╠═d64772d4-0fda-11eb-171a-a902e70284c7
# ╠═8f517d88-0fdb-11eb-0b8a-5b3d661a8dad
# ╠═853d003e-0fda-11eb-068e-a7f659325b4a
# ╠═3a7572dc-0fdc-11eb-3a1f-e3dfaeb46838
# ╠═3b8d4802-0fdc-11eb-2df2-0d877ec3ab96
# ╠═b7d4a72a-105e-11eb-3582-af78a865e0b4
# ╠═fe403ff8-107c-11eb-3cb2-4fcee90989ce
# ╠═b57ee2dc-1078-11eb-180a-63f457b83147
# ╠═2aa7f6e6-1080-11eb-05a3-99a85b4bc22d
# ╠═e36baec8-107d-11eb-28bf-0f019441c2b7
# ╠═aa67a4bc-1080-11eb-3923-0b6287c32562
# ╠═18291724-1081-11eb-044a-af3ebe5a8a37
# ╠═4375a384-1081-11eb-060a-c9ec078121c0
# ╠═956a5db0-1081-11eb-3bf3-25df114db076
# ╠═31026d8c-1083-11eb-3df8-79ba8e6fa761
# ╠═0a0fc124-1083-11eb-2fc5-076188d12ed9
# ╠═5e22132a-1086-11eb-11a9-abde1f5e2112
# ╠═75395cac-1087-11eb-3b5a-c3123503b6cd
# ╠═ce5298a8-1087-11eb-0c3b-ada77ce848c6
# ╠═5147ed40-1087-11eb-00ec-6d3693cb2012
# ╠═7b0706b8-1085-11eb-23c9-419e48bacc00
# ╠═51d7cd2e-1083-11eb-2e9b-a1701faa993d
