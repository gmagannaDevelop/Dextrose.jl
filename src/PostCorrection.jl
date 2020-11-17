### A Pluto.jl notebook ###
# v0.12.10

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

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
# Post-Correction Analysis
"""

# ╔═╡ f2eecdea-0d98-11eb-2b2d-fb07509edcae
pwd()

# ╔═╡ 2d7461a4-0d9a-11eb-1ce3-73e77884798e
Base.load_path()

# ╔═╡ d05462fc-1076-11eb-0421-310c1326ed21
data_dir = "../data/"

# ╔═╡ 5dcea10c-0d9a-11eb-2f9f-434a79f73daa
data_entries = data_dir .* readdir(data_dir)

# ╔═╡ 48b358f0-290e-11eb-26d2-915fc98810d6
data_entries[end]

# ╔═╡ 6ecd7716-290e-11eb-2a74-ed6abdbb6ab8


# ╔═╡ 7dffdc3e-0fd9-11eb-1110-e9d5e0afcea7
data = CSV.read(data_entries[end], DataFrame);

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
	MAX_INSULIN_DURATION = 180-1;
	POSTPRANDIAL_TIME = 150-1;
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

# ╔═╡ fe403ff8-107c-11eb-3cb2-4fcee90989ce
collect(correction_insulin_total)

# ╔═╡ 2aa7f6e6-1080-11eb-05a3-99a85b4bc22d
# Better : 
correction_idx = findall(x -> !ismissing(x) && x > 0.0, correction_insulin_estimate);

# ╔═╡ e36baec8-107d-11eb-28bf-0f019441c2b7
true_corrections = correction_insulin_estimate[correction_idx];

# ╔═╡ 4375a384-1081-11eb-060a-c9ec078121c0
correction_timestamps = dates[correction_idx];

# ╔═╡ 745b58dc-16ac-11eb-23e4-b34d14a87075
md"""
__To do__
	
benchmark both approaches :
"""

# ╔═╡ 75395cac-1087-11eb-3b5a-c3123503b6cd
# Approach 1
begin
	# Upper bound for array size :
	max_idx = length(glycaemia);
	post_correction_intervals = [
	# Define up to MAX_INSULIN_DURATION steps i.e. 3 hours after each corrrection :
		val:1:(x -> (max_idx >= x) ? x : max_idx)(val+MAX_INSULIN_DURATION)
		for val in correction_idx
	];
	nothing
end

# ╔═╡ 15c0b6f6-16ab-11eb-275d-2db41ee18f68
# Approach 2
begin
	my_post_correction_intervals = [
		val:1:rebound(glycaemia, val+MAX_INSULIN_DURATION)
		for val in correction_idx
	];	
	nothing
end

# ╔═╡ 9aeaac6e-16ac-11eb-3eb3-7b7a90989c48
md"""
Note that they do produce identical results, as expected :
"""

# ╔═╡ f9867e84-16ab-11eb-0226-4d21d321d993
reduce((x, y) -> x*y, post_correction_intervals .== my_post_correction_intervals)

# ╔═╡ 6e64793e-10af-11eb-1ec7-9f12559b0694
post_correction_glycaemiae = [
	replace(glycaemia[interval], missing=>NaN)
	for interval in post_correction_intervals
];

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

# ╔═╡ fa58cfb6-16be-11eb-2d91-d9d33171ace2
@bind ith_interval Slider(1:length(post_correction_intervals))

# ╔═╡ fca292cc-10ae-11eb-1e3f-173688dc10f9
plot(glycaemia[post_correction_intervals[ith_interval]])

# ╔═╡ 11a3ff50-16c0-11eb-3a43-6b96c4fdd2b6
md"""
# Visualise all post correction intervals
"""

# ╔═╡ 5653b12c-16be-11eb-1048-03ff05547d18
plot_intervals(glycaemia, post_correction_intervals)

# ╔═╡ 307d5d8e-16d6-11eb-0ed6-75c99eb1bda0
post_correction_intervals

# ╔═╡ 259bf116-16c0-11eb-184a-cd6600a7385d
md"""
This is sub-optimal, not only do we have different behaviours, we have too many lines to actually understand the trends. This is why we will have to perform clustering.
"""

# ╔═╡ 9cc06748-10ad-11eb-158b-81c35d9cd021
post_correction_intervals[1]

# ╔═╡ 1f79b3ee-16d0-11eb-0875-91ac3b092514
[ _int[1][1] for _int in post_correction_intervals ]

# ╔═╡ b68e197e-10ad-11eb-31b5-0dbf62272a4e
glycaemia[36:1:216]

# ╔═╡ 7e14a9d0-108a-11eb-1ab4-4d9994d436c7
pglc = replace(glycaemia, missing=>NaN)

# ╔═╡ 5f0b6b22-15d8-11eb-218d-756ea3fe9445
_cluster_original_columns = [
	"x(t)", "y(t)", 									# Time
	"Sensor Glucose (mg/dL)", "BWZ BG Input (mg/dL)",   # Glucose
	"d1w5", "Sd1w5",									# Trends
	"BWZ Insulin Sensitivity (mg/dL/U)",				# Params
	"BWZ Target High BG (mg/dL)", 						# Objectives
	"BWZ Target Low BG (mg/dL)"
];

# ╔═╡ 69934a6c-16b2-11eb-3b13-dd35e12e9ef5
_cluster_cols = [
	"x(t)" => :x, "y(t)" => :y,
	"Sensor Glucose (mg/dL)" => :sensor, 
	"BWZ BG Input (mg/dL)" => :bg,  
	"d1w5" => :d1w5, "Sd1w5" => :Sd1w5,									
	"BWZ Insulin Sensitivity (mg/dL/U)" => :sensitivity,				
	"BWZ Target High BG (mg/dL)" => :htarget, 						
	"BWZ Target Low BG (mg/dL)" => :ltarget
];

# ╔═╡ 7671c05a-15d7-11eb-09d5-398891c3f600
correction_cluster = data[correction_idx, _cluster_original_columns];

# ╔═╡ 4c049094-16b4-11eb-2ef5-994676dbfd04
rename!(correction_cluster, _cluster_cols);

# ╔═╡ 49709ace-16b1-11eb-3fed-9592e8d52e39
_desc = describe(correction_cluster);

# ╔═╡ da5430dc-16b1-11eb-3834-1d71ce5b4de2
[ nm => param  for (nm, param) in zip(names(correction_cluster), _desc.nmissing)]

# ╔═╡ 8a696ec0-16c0-11eb-29b0-0349fb409e04
begin
	correction_cluster["idx"] = correction_idx; #ID inside original DataFrame
	correction_cluster["datetime"] = correction_timestamps;
	nothing
end

# ╔═╡ 5452520a-16b3-11eb-24d5-3537343372f4
_grouping_cluster = correction_cluster[:, [:x, :y]];

# ╔═╡ 65a8f800-16b4-11eb-0051-5b2b692994f9
md"""
## Variable selection rationale
Adding other parameters for the grouping could introduce some artifacts, which is obviously undefined behaviour. Wanting to evaluate the homogeneity of correction curves as a function of time, this are the only parameters that should be taken into account.

The selected variables are ```:x``` and ```:y```, which are defined as follows :
\begin{equation}
	\begin{aligned}
		& x(t) = cos\biggl( \frac{2 \times \pi \times t}{T} \biggr) \\
		& y(t) = sin\biggl( \frac{2 \times \pi \times t}{T} \biggr)
	\end{aligned}
\end{equation}

Where $t$ is the total amount of minutes since midnight (i.e. when that day started).
\begin{equation}
	t \in [0, 1440[
\end{equation}

"""

# ╔═╡ 8f413c0c-16c5-11eb-3c87-292c1b3041fd
begin
	# Definition of parametric time operations 
	T = 1439;
	xₜ(t) = cos((2π * t) / T );
	yₜ(t) = sin((2π * t) / T );
	_xₜ(t) = cos(t);
	_yₜ(t) = sin(t);
	tx(x) = T*acos(x) / 2π;
	ty(y) = T*asin(y) / 2π;
	"Definition of parametric time functions "
end

# ╔═╡ 5a116890-16b6-11eb-16f8-b9b19cd27def
md"""
Hour slider : $(@bind _untill Slider(1:1:1440, show_value=false))

$(@bind go Button("Restart plot"))
"""

# ╔═╡ 06948e56-16b9-11eb-3f2f-f7fccdf7f6a9
let
	go
	_t_demo = plot(_xₜ, _yₜ, 0, 2π, leg=false);
	nothing
end

# ╔═╡ 98c26fa0-16b6-11eb-3cb1-1998acef59bc
begin
	go
	_minute = 1:_untill;
	xt = @. cos( 2.0 * π * _untill / T);
	yt = @. sin( 2.0 * π * _untill / T);
	scatter!([xt], [yt])
	hora = "$(Int(round(_untill / 60))):$(_untill % (60))"
	title!("Hour $hora")
end

# ╔═╡ a6e3ad06-16bc-11eb-21e7-4191239a6eaa
md"""
## Clustering 
"""

# ╔═╡ 159bd290-15df-11eb-120c-8be93915a01e
begin
	features = collect(Matrix(_grouping_cluster)'); # features to use for clustering
	result = kmeans(features, 3, display=:iter) # run K-means for the 3 clusters
	correction_cluster["group"] = result.assignments;
	nothing
end

# ╔═╡ 811a441a-16bc-11eb-018a-1794e5101a65
[ id => clust for (id, clust) in 
	zip(correction_cluster.idx, correction_cluster.group) 
]

# ╔═╡ b49ee768-16c2-11eb-1c16-c3dcee88a2b7
md"""
Are our clusters what we expected ?
"""

# ╔═╡ 95d5ff92-16b3-11eb-2386-d7077ea3f7c0
Hour.(correction_cluster.datetime)

# ╔═╡ b4091c56-16b3-11eb-0a32-1749b30fc328
correction_cluster.group

# ╔═╡ cab2fc1c-16c2-11eb-2273-154e13cc875e
md"""
yes
"""

# ╔═╡ 1f49e46e-16c3-11eb-2f45-65e21f4dfb7b
# Create a Dict containing cluster_numer => cluster_center

# ╔═╡ e9b5b152-16c7-11eb-10c4-bd74d8343194
Time(correction_cluster.datetime[1])

# ╔═╡ e1aac27c-16c7-11eb-24ab-69045ea2a376
hour_by_group = Dict([
	# group was determined by kmeans
	group => [ 
		# We iterate over all corrections, but keep only those belonging
		# to the current group of the comprehension.
		Time(correction.datetime) for correction in eachrow(correction_cluster) 
		if correction.group == group 
	] for group in unique(correction_cluster.group)
])

# ╔═╡ b383b7e8-16c2-11eb-1045-6b174accd26a
idx_by_group = Dict([
	# iterate over groups, determined by kmeans
	group => [ 
		# keep the index of corrections belongin to the current cluster :
		correction.idx for correction in eachrow(correction_cluster) 
		if correction.group == group 
	] for group in unique(correction_cluster.group)
])

# ╔═╡ 41bdcac2-16d4-11eb-0bb9-b78b70e243bf
intervals_by_group = Dict([ 
	key => create_intervals(glycaemia, value) 
	for (key, value) in idx_by_group
])

# ╔═╡ 928bdc36-16d5-11eb-0b72-6ded2d2a2ce6
glycaemiae_by_group = Dict([
	group => [glycaemia[interval] for interval in intervals] 
		for (group, intervals) in intervals_by_group
])

# ╔═╡ 512c3aec-16d3-11eb-2183-8b56b9d2dd69
plot_intervals(glycaemia, intervals_by_group[1], mean_time(hour_by_group[1]))

# ╔═╡ 5f74485a-16d6-11eb-1ad4-47b17811be73
plot_intervals(glycaemia, intervals_by_group[2], mean_time(hour_by_group[2]))

# ╔═╡ 70b8e01c-16d6-11eb-00c1-c1e8685ad1a8
plot_intervals(glycaemia, intervals_by_group[3], mean_time(hour_by_group[3]))

# ╔═╡ 858d4fa8-16c4-11eb-1444-67f98d95b4ec
result.centers

# ╔═╡ bca0ad44-16f8-11eb-2183-63e9a36c1b99
dummy_intervals = intervals_by_group[1]

# ╔═╡ ef5cc1d2-16f8-11eb-2aa7-59356782ac83
glycaemia[dummy_intervals[1]] .- glycaemia[dummy_intervals[1]][1]

# ╔═╡ 014813d2-16fa-11eb-1a2a-7ffe9e01d4ee


# ╔═╡ 6724948a-170b-11eb-2a7a-9d2a7709fa53
normalised_glycaemia = deepcopy(glycaemia)

# ╔═╡ db043496-170d-11eb-1f42-19b5a7cbc789
plot_intervals(normalised_glycaemia, intervals_by_group[2][1:2], mean_time(hour_by_group[2]))

# ╔═╡ 5f95e544-170f-11eb-02fa-634d2f5ff7d5
plot_intervals(glycaemia, intervals_by_group[2][1:2], mean_time(hour_by_group[2]))

# ╔═╡ b79d793e-16f9-11eb-1f92-29ec9080fb0b
post_correction_glycaemiae

# ╔═╡ 6ede9de2-16f9-11eb-3c75-850f24e8f007
function substract_first(array)
	_initial = array[1]
	array .- _initial
end

# ╔═╡ 27a9605e-16f9-11eb-3be0-fb978268ddce
substract_first.(post_correction_glycaemiae)

# ╔═╡ a1be6710-170b-11eb-04eb-69937b4b49ba
for interval in post_correction_intervals
	normalised_glycaemia[interval] = substract_first(normalised_glycaemia[interval]) 
end

# ╔═╡ b6462954-170b-11eb-1297-efe0f592f191
function substract_first!(array)
	for i in 1:length(array)
		array[i] = array[i] - array[1]
	end
end

# ╔═╡ ccbd0a66-170b-11eb-2d6a-93ce3fef3b53
foo = collect(reverse(50:100))

# ╔═╡ 0ec2dbb2-1710-11eb-18ba-5dd77800e918
foo

# ╔═╡ dfdb45e2-170b-11eb-02e3-0d3f5e7fd782
substract_first(foo)

# ╔═╡ e7113400-170b-11eb-1c6c-77595c53dfda
foo

# ╔═╡ Cell order:
# ╟─7e3846de-0d98-11eb-16ca-b3b6fd290a22
# ╠═f2eecdea-0d98-11eb-2b2d-fb07509edcae
# ╠═2d7461a4-0d9a-11eb-1ce3-73e77884798e
# ╠═37374272-0d9a-11eb-1eb1-65c867f1d867
# ╠═4569bd20-0d9a-11eb-30c0-d98f9f6b3306
# ╠═d05462fc-1076-11eb-0421-310c1326ed21
# ╠═5dcea10c-0d9a-11eb-2f9f-434a79f73daa
# ╠═48b358f0-290e-11eb-26d2-915fc98810d6
# ╠═6ecd7716-290e-11eb-2a74-ed6abdbb6ab8
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
# ╠═fe403ff8-107c-11eb-3cb2-4fcee90989ce
# ╠═2aa7f6e6-1080-11eb-05a3-99a85b4bc22d
# ╠═e36baec8-107d-11eb-28bf-0f019441c2b7
# ╠═4375a384-1081-11eb-060a-c9ec078121c0
# ╟─745b58dc-16ac-11eb-23e4-b34d14a87075
# ╠═75395cac-1087-11eb-3b5a-c3123503b6cd
# ╠═15c0b6f6-16ab-11eb-275d-2db41ee18f68
# ╟─9aeaac6e-16ac-11eb-3eb3-7b7a90989c48
# ╠═f9867e84-16ab-11eb-0226-4d21d321d993
# ╠═6e64793e-10af-11eb-1ec7-9f12559b0694
# ╠═c1fa1ee4-10b1-11eb-04da-6f20f625300c
# ╠═435ac9c6-10b1-11eb-0ddf-037aa511a711
# ╠═97098eac-10b3-11eb-3fa5-8fcad27cc6b3
# ╠═186f2058-10bf-11eb-1c79-d970f3d30b53
# ╠═57a2c29c-10bf-11eb-0ad1-c5aa51f6b6db
# ╠═fca292cc-10ae-11eb-1e3f-173688dc10f9
# ╠═fa58cfb6-16be-11eb-2d91-d9d33171ace2
# ╟─11a3ff50-16c0-11eb-3a43-6b96c4fdd2b6
# ╠═5653b12c-16be-11eb-1048-03ff05547d18
# ╠═307d5d8e-16d6-11eb-0ed6-75c99eb1bda0
# ╟─259bf116-16c0-11eb-184a-cd6600a7385d
# ╠═9cc06748-10ad-11eb-158b-81c35d9cd021
# ╠═1f79b3ee-16d0-11eb-0875-91ac3b092514
# ╠═b68e197e-10ad-11eb-31b5-0dbf62272a4e
# ╠═7e14a9d0-108a-11eb-1ab4-4d9994d436c7
# ╠═5f0b6b22-15d8-11eb-218d-756ea3fe9445
# ╠═69934a6c-16b2-11eb-3b13-dd35e12e9ef5
# ╠═7671c05a-15d7-11eb-09d5-398891c3f600
# ╠═4c049094-16b4-11eb-2ef5-994676dbfd04
# ╠═49709ace-16b1-11eb-3fed-9592e8d52e39
# ╠═da5430dc-16b1-11eb-3834-1d71ce5b4de2
# ╠═8a696ec0-16c0-11eb-29b0-0349fb409e04
# ╠═5452520a-16b3-11eb-24d5-3537343372f4
# ╟─65a8f800-16b4-11eb-0051-5b2b692994f9
# ╟─8f413c0c-16c5-11eb-3c87-292c1b3041fd
# ╟─06948e56-16b9-11eb-3f2f-f7fccdf7f6a9
# ╟─98c26fa0-16b6-11eb-3cb1-1998acef59bc
# ╟─5a116890-16b6-11eb-16f8-b9b19cd27def
# ╟─a6e3ad06-16bc-11eb-21e7-4191239a6eaa
# ╠═159bd290-15df-11eb-120c-8be93915a01e
# ╠═811a441a-16bc-11eb-018a-1794e5101a65
# ╟─b49ee768-16c2-11eb-1c16-c3dcee88a2b7
# ╠═95d5ff92-16b3-11eb-2386-d7077ea3f7c0
# ╠═b4091c56-16b3-11eb-0a32-1749b30fc328
# ╟─cab2fc1c-16c2-11eb-2273-154e13cc875e
# ╠═1f49e46e-16c3-11eb-2f45-65e21f4dfb7b
# ╠═e9b5b152-16c7-11eb-10c4-bd74d8343194
# ╠═e1aac27c-16c7-11eb-24ab-69045ea2a376
# ╠═b383b7e8-16c2-11eb-1045-6b174accd26a
# ╠═41bdcac2-16d4-11eb-0bb9-b78b70e243bf
# ╠═928bdc36-16d5-11eb-0b72-6ded2d2a2ce6
# ╠═512c3aec-16d3-11eb-2183-8b56b9d2dd69
# ╠═5f74485a-16d6-11eb-1ad4-47b17811be73
# ╠═70b8e01c-16d6-11eb-00c1-c1e8685ad1a8
# ╠═858d4fa8-16c4-11eb-1444-67f98d95b4ec
# ╠═bca0ad44-16f8-11eb-2183-63e9a36c1b99
# ╠═ef5cc1d2-16f8-11eb-2aa7-59356782ac83
# ╠═014813d2-16fa-11eb-1a2a-7ffe9e01d4ee
# ╠═27a9605e-16f9-11eb-3be0-fb978268ddce
# ╠═6724948a-170b-11eb-2a7a-9d2a7709fa53
# ╠═a1be6710-170b-11eb-04eb-69937b4b49ba
# ╠═db043496-170d-11eb-1f42-19b5a7cbc789
# ╠═5f95e544-170f-11eb-02fa-634d2f5ff7d5
# ╠═b79d793e-16f9-11eb-1f92-29ec9080fb0b
# ╠═6ede9de2-16f9-11eb-3c75-850f24e8f007
# ╠═b6462954-170b-11eb-1297-efe0f592f191
# ╠═ccbd0a66-170b-11eb-2d6a-93ce3fef3b53
# ╠═0ec2dbb2-1710-11eb-18ba-5dd77800e918
# ╠═dfdb45e2-170b-11eb-02e3-0d3f5e7fd782
# ╠═e7113400-170b-11eb-1c6c-77595c53dfda
