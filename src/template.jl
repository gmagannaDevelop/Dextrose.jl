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
	using Clustering
	using ShiftedArrays
	using Statistics
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
data = CSV.read(data_entries[end]);

# ╔═╡ 4178c9d2-0fda-11eb-3a43-376139cd6f28
names(data)

# ╔═╡ 3f95c168-105e-11eb-2c3d-f3f9dbbbcd9a
md"""
## Extract useful information 
"""

# ╔═╡ 6b74c526-0fdd-11eb-0e44-b922ac9e901f
begin
	basal = data["Basal Rate (U/h)"];
	glycaemia = data["Sensor Glucose (mg/dL)"];
	sensitivity = data["BWZ Insulin Sensitivity (mg/dL/U)"];
	ratio =  data["BWZ Carb Ratio (g/U)"];
	carb_insulin = data["BWZ Food Estimate (U)"];
	correction_insulin_estimate = data["BWZ Correction Estimate (U)"];
	active_insulin = data["BWZ Active Insulin (U)"];
	correction_insulin_total = correction_insulin_estimate .+ active_insulin;
end

# ╔═╡ 0d97d446-10b1-11eb-1bf4-fdc718b0f8a8
replace!(glycaemia, missing=>NaN) 

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

# ╔═╡ ef669004-16a8-11eb-2e65-778dffc982bd
md"""
### Define some useful parameters with `Constant` naming convention
"""

# ╔═╡ 58d8d484-16a9-11eb-08ec-772c5d102931
begin
	# Block of constants :
	## Time constants, in minutes :
	MAX_INSULIN_DURATION = 180;
	POSTPRANDIAL_TIME = 150;
end

# ╔═╡ c41cf2d8-16aa-11eb-3198-5fa6e26fbc45
md"""
### Define some utility functions :
"""

# ╔═╡ 2ea0ffa8-16a8-11eb-16f5-357a78e0fbd5
"""
Take an Array (some_array) and an index (n).

Returns 
	`n` if it is inbounds (i.e. n <= length(some_array)
	`length(some_array)` otherwise
"""
function rebound(some_array, n)
	# bound the upper limit to max array length
	arr_size = length(some_array);
	n <= arr_size ? n : arr_size 
end

# ╔═╡ 17c941da-16be-11eb-190b-6df85ec71bb8
"""
Doc pending, 
sub-optimal and perhaps non-julian
"""
function plot_intervals(full_series, intervals, _title)
	_pp = plot();
	[ plot!(_pp, full_series[interval]) for interval in intervals ];
	title!(_title)	
	_pp
end

# ╔═╡ 556a481c-16d8-11eb-3dd0-af683cf7893f
"""
Doc pending, 
sub-optimal and perhaps non-julian
"""
function plot_intervals(full_series, intervals)
	_pp = plot();
	[ plot!(_pp, full_series[interval]) for interval in intervals ];
	_pp
end

# ╔═╡ 8bdc4bec-16d4-11eb-38f0-236816ec38cd
"""
	Create intervals of length Main.MAX_INSULIN_DURATION,
	respectin the size of the array `full_data`.
"""
function create_intervals(full_data, starting_points)
	[ val:1:rebound(full_data, val+MAX_INSULIN_DURATION)
		for val in starting_points
	]
end

# ╔═╡ bdb3c432-16da-11eb-2601-a17cdd87d07c
"""
	¿Cómo chingados no se va a poder calcular la media 
	de las horas del día?
"""
function mean_time(times_array)
	_unix_mean_tmp = Libc.strftime(mean(Dates.value.(times_array)))
	rem = match(r"\d{2}:\d{2}:\d{2}", _unix_mean_tmp)
	rem.match
end

# ╔═╡ 6e64793e-10af-11eb-1ec7-9f12559b0694
post_correction_glycaemiae = [
	replace(glycaemia[interval], missing=>NaN)
	for interval in post_correction_intervals
];

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
# ╠═0d97d446-10b1-11eb-1bf4-fdc718b0f8a8
# ╠═b8dca518-0fda-11eb-1e7e-edc7d359bf5e
# ╠═d64772d4-0fda-11eb-171a-a902e70284c7
# ╠═8f517d88-0fdb-11eb-0b8a-5b3d661a8dad
# ╠═853d003e-0fda-11eb-068e-a7f659325b4a
# ╠═3a7572dc-0fdc-11eb-3a1f-e3dfaeb46838
# ╠═3b8d4802-0fdc-11eb-2df2-0d877ec3ab96
# ╠═b7d4a72a-105e-11eb-3582-af78a865e0b4
# ╟─ef669004-16a8-11eb-2e65-778dffc982bd
# ╠═58d8d484-16a9-11eb-08ec-772c5d102931
# ╟─c41cf2d8-16aa-11eb-3198-5fa6e26fbc45
# ╠═2ea0ffa8-16a8-11eb-16f5-357a78e0fbd5
# ╠═17c941da-16be-11eb-190b-6df85ec71bb8
# ╠═556a481c-16d8-11eb-3dd0-af683cf7893f
# ╠═8bdc4bec-16d4-11eb-38f0-236816ec38cd
# ╠═bdb3c432-16da-11eb-2601-a17cdd87d07c
# ╠═6e64793e-10af-11eb-1ec7-9f12559b0694
