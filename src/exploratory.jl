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

# ╔═╡ fe403ff8-107c-11eb-3cb2-4fcee90989ce
collect(correction_insulin_total)

# ╔═╡ b57ee2dc-1078-11eb-180a-63f457b83147
# Goed :
# correction_idx = findall(!ismissing, correction_insulin_estimate)

# ╔═╡ 2aa7f6e6-1080-11eb-05a3-99a85b4bc22d
# Better : 
correction_idx = findall(x -> !ismissing(x) && x > 0.0, correction_insulin_estimate)

# ╔═╡ e36baec8-107d-11eb-28bf-0f019441c2b7
true_corrections = correction_insulin_estimate[correction_idx]

# ╔═╡ 4375a384-1081-11eb-060a-c9ec078121c0
correction_timestamps = dates[correction_idx]

# ╔═╡ 75395cac-1087-11eb-3b5a-c3123503b6cd
begin
	# Upper bound for array size :
	max_idx = length(glycaemia)
	post_correction_intervals = [
		# Define 180 steps i.e. 3 hours after each corrrection :
		val:1:(x -> (max_idx >= x) ? x : max_idx)(val+180)
		for val in correction_idx
	]
end

# ╔═╡ 6e64793e-10af-11eb-1ec7-9f12559b0694
post_correction_glycaemiae = [
	replace(glycaemia[interval], missing=>NaN)
	for interval in post_correction_intervals
]

# ╔═╡ c1fa1ee4-10b1-11eb-04da-6f20f625300c
[ window for window in post_correction_glycaemiae ]

# ╔═╡ 435ac9c6-10b1-11eb-0ddf-037aa511a711
#begin
#	_p = plot()
#	for window in post_correction_glycaemiae
#		_p = plot!(window)
#	end
#end

# ╔═╡ 97098eac-10b3-11eb-3fa5-8fcad27cc6b3
#begin
#	plot()
#	for window in post_correction_glycaemiae
#		plot!(window)
#	end
#end

# ╔═╡ 186f2058-10bf-11eb-1c79-d970f3d30b53
#display(_p)

# ╔═╡ 57a2c29c-10bf-11eb-0ad1-c5aa51f6b6db
unique([ length(episode) for episode in post_correction_glycaemiae ])

# ╔═╡ ce5298a8-1087-11eb-0c3b-ada77ce848c6
#glycaemia[post_correction_intervals[3]]

# ╔═╡ 161b8db2-10af-11eb-0a6e-c3720ff071d1
#glycaemia[post_correction_intervals[6]]

# ╔═╡ fca292cc-10ae-11eb-1e3f-173688dc10f9
#plot(glycaemia[post_correction_intervals[35]])

# ╔═╡ 19476ce8-10c0-11eb-22d9-cf97f2019dcb
_pp = plot();

# ╔═╡ 7f238eee-108a-11eb-1918-3500aeeb8a42
post_correction_plots = [
	plot!(_pp, glycaemia[interval]) for interval in post_correction_intervals
];

# ╔═╡ de882d6a-10b3-11eb-285b-4b6ceb1d0581
_pp

# ╔═╡ 9cc06748-10ad-11eb-158b-81c35d9cd021
post_correction_intervals[1]

# ╔═╡ b68e197e-10ad-11eb-31b5-0dbf62272a4e
glycaemia[36:1:216]

# ╔═╡ 7e14a9d0-108a-11eb-1ab4-4d9994d436c7
pglc = replace(glycaemia, missing=>NaN)

# ╔═╡ aeea95dc-108a-11eb-336f-a198862ac5f1
#plot(pglc[interval[1]])

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
# ╠═0d97d446-10b1-11eb-1bf4-fdc718b0f8a8
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
# ╠═4375a384-1081-11eb-060a-c9ec078121c0
# ╠═75395cac-1087-11eb-3b5a-c3123503b6cd
# ╠═6e64793e-10af-11eb-1ec7-9f12559b0694
# ╠═c1fa1ee4-10b1-11eb-04da-6f20f625300c
# ╠═435ac9c6-10b1-11eb-0ddf-037aa511a711
# ╠═97098eac-10b3-11eb-3fa5-8fcad27cc6b3
# ╠═186f2058-10bf-11eb-1c79-d970f3d30b53
# ╠═57a2c29c-10bf-11eb-0ad1-c5aa51f6b6db
# ╠═ce5298a8-1087-11eb-0c3b-ada77ce848c6
# ╠═161b8db2-10af-11eb-0a6e-c3720ff071d1
# ╠═fca292cc-10ae-11eb-1e3f-173688dc10f9
# ╠═19476ce8-10c0-11eb-22d9-cf97f2019dcb
# ╠═7f238eee-108a-11eb-1918-3500aeeb8a42
# ╠═de882d6a-10b3-11eb-285b-4b6ceb1d0581
# ╠═9cc06748-10ad-11eb-158b-81c35d9cd021
# ╠═b68e197e-10ad-11eb-31b5-0dbf62272a4e
# ╠═7e14a9d0-108a-11eb-1ab4-4d9994d436c7
# ╠═aeea95dc-108a-11eb-336f-a198862ac5f1
# ╠═5147ed40-1087-11eb-00ec-6d3693cb2012
# ╠═7b0706b8-1085-11eb-23c9-419e48bacc00
# ╠═51d7cd2e-1083-11eb-2e9b-a1701faa993d
