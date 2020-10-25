### A Pluto.jl notebook ###
# v0.12.4

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
end

# ╔═╡ 280e2d62-15d8-11eb-0d3a-b5d9d044e540
begin
	using RDatasets
	iris = dataset("datasets", "iris"); # load the data
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
end

# ╔═╡ 15c0b6f6-16ab-11eb-275d-2db41ee18f68
# Approach 2
begin
	my_post_correction_intervals = [
		val:1:rebound(glycaemia, val+MAX_INSULIN_DURATION)
		for val in correction_idx
	];	
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

# ╔═╡ ce5298a8-1087-11eb-0c3b-ada77ce848c6
#glycaemia[post_correction_intervals[3]]

# ╔═╡ 161b8db2-10af-11eb-0a6e-c3720ff071d1
#glycaemia[post_correction_intervals[6]]

# ╔═╡ fca292cc-10ae-11eb-1e3f-173688dc10f9
plot(glycaemia[post_correction_intervals[2]])

# ╔═╡ 9cf41598-16a6-11eb-211a-63cf800d12f4
post_correction_intervals2 = [
	interv[1: post_correction_intervals
]

# ╔═╡ f92113d4-16a9-11eb-36f7-e5a3a3d8c03c
bar = post_correction_intervals[4][1:120]

# ╔═╡ 9806bed8-16aa-11eb-283a-636179c5485f
rebound(bar, 180)

# ╔═╡ 0a199a9c-16a7-11eb-1947-a7fc5bcc0031
Int(round(((x, y) -> x * y)(, 0.010 * wnd)))

# ╔═╡ f1a88f54-16a6-11eb-2f89-c3ef6bc3a31d
post_correction_intervals[1][end]

# ╔═╡ bc7d03be-16a6-11eb-2d23-c937fa9f8347
@bind wnd Slider(1:1:MAX_INSULIN_DURATION, show_value=true)

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

# ╔═╡ 5f0b6b22-15d8-11eb-218d-756ea3fe9445
_cluster_original_columns = [
	"x(t)", "y(t)", 									# Time
	"Sensor Glucose (mg/dL)", "BWZ BG Input (mg/dL)",   # Glucose
	"d1w5", "Sd1w5",									# Trends
	"BWZ Insulin Sensitivity (mg/dL/U)",				# Params
	"BWZ Target High BG (mg/dL)", 						# Objectives
	"BWZ Target Low BG (mg/dL)"
]

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

# ╔═╡ f869ad1c-16b7-11eb-1845-23e27356f9a8
begin
	xₜ(t) = cos(t);
	yₜ(t) = sin(t);
	nothing
end

# ╔═╡ 5a116890-16b6-11eb-16f8-b9b19cd27def
md"""
Hour slider : $(@bind _untill Slider(1:1:1440, show_value=false))

$(@bind go Button("Restart plot"))
"""

# ╔═╡ 06948e56-16b9-11eb-3f2f-f7fccdf7f6a9
let
	go
	_t_demo = plot(xₜ, yₜ, 0, 2π, leg=false);
	nothing
end

# ╔═╡ 98c26fa0-16b6-11eb-3cb1-1998acef59bc
begin
	go
	T = 1439;
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
end

# ╔═╡ 811a441a-16bc-11eb-018a-1794e5101a65


# ╔═╡ 95d5ff92-16b3-11eb-2386-d7077ea3f7c0


# ╔═╡ b4091c56-16b3-11eb-0a32-1749b30fc328
correction_cluster.group

# ╔═╡ ea460916-15ee-11eb-3ac9-9d4719381122
#mapcols(x -> lag(x, MAX_INSULIN_DURATION), 
#	correction_cluster)["Sensor Glucose (mg/dL)"]

# ╔═╡ 5a15e856-15d8-11eb-1bc3-d5a604de961c
#copy(data, copycols=true)

# ╔═╡ e26f2218-15e9-11eb-0e6b-ff9587bfa122
begin
	_features = collect(Matrix(iris[:, 1:4])'); # features to use for clustering
	_result = kmeans(_features, 3); # run K-means for the 3 clusters

	# plot with the point color mapped to the assigned cluster index
	scatter(iris.PetalLength, iris.PetalWidth, marker_z=_result.assignments,
    	    color=:lightrainbow, legend=false)
end

# ╔═╡ 94f15490-15ea-11eb-1844-279f40b325cb
_features

# ╔═╡ ee049980-15d7-11eb-17de-85bf4b27321a
names(data)

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
# ╠═fe403ff8-107c-11eb-3cb2-4fcee90989ce
# ╠═b57ee2dc-1078-11eb-180a-63f457b83147
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
# ╠═ce5298a8-1087-11eb-0c3b-ada77ce848c6
# ╠═161b8db2-10af-11eb-0a6e-c3720ff071d1
# ╠═fca292cc-10ae-11eb-1e3f-173688dc10f9
# ╠═9cf41598-16a6-11eb-211a-63cf800d12f4
# ╠═f92113d4-16a9-11eb-36f7-e5a3a3d8c03c
# ╠═9806bed8-16aa-11eb-283a-636179c5485f
# ╠═0a199a9c-16a7-11eb-1947-a7fc5bcc0031
# ╠═f1a88f54-16a6-11eb-2f89-c3ef6bc3a31d
# ╠═bc7d03be-16a6-11eb-2d23-c937fa9f8347
# ╠═19476ce8-10c0-11eb-22d9-cf97f2019dcb
# ╠═7f238eee-108a-11eb-1918-3500aeeb8a42
# ╠═de882d6a-10b3-11eb-285b-4b6ceb1d0581
# ╠═9cc06748-10ad-11eb-158b-81c35d9cd021
# ╠═b68e197e-10ad-11eb-31b5-0dbf62272a4e
# ╠═7e14a9d0-108a-11eb-1ab4-4d9994d436c7
# ╠═5f0b6b22-15d8-11eb-218d-756ea3fe9445
# ╠═69934a6c-16b2-11eb-3b13-dd35e12e9ef5
# ╠═7671c05a-15d7-11eb-09d5-398891c3f600
# ╠═4c049094-16b4-11eb-2ef5-994676dbfd04
# ╠═49709ace-16b1-11eb-3fed-9592e8d52e39
# ╠═da5430dc-16b1-11eb-3834-1d71ce5b4de2
# ╠═5452520a-16b3-11eb-24d5-3537343372f4
# ╟─65a8f800-16b4-11eb-0051-5b2b692994f9
# ╟─f869ad1c-16b7-11eb-1845-23e27356f9a8
# ╟─5a116890-16b6-11eb-16f8-b9b19cd27def
# ╟─06948e56-16b9-11eb-3f2f-f7fccdf7f6a9
# ╟─98c26fa0-16b6-11eb-3cb1-1998acef59bc
# ╠═a6e3ad06-16bc-11eb-21e7-4191239a6eaa
# ╠═159bd290-15df-11eb-120c-8be93915a01e
# ╠═811a441a-16bc-11eb-018a-1794e5101a65
# ╠═95d5ff92-16b3-11eb-2386-d7077ea3f7c0
# ╠═b4091c56-16b3-11eb-0a32-1749b30fc328
# ╠═ea460916-15ee-11eb-3ac9-9d4719381122
# ╠═5a15e856-15d8-11eb-1bc3-d5a604de961c
# ╠═280e2d62-15d8-11eb-0d3a-b5d9d044e540
# ╠═e26f2218-15e9-11eb-0e6b-ff9587bfa122
# ╠═94f15490-15ea-11eb-1844-279f40b325cb
# ╠═ee049980-15d7-11eb-17de-85bf4b27321a
