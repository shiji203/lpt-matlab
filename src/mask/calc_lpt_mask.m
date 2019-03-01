clear all
close all


%%%% Set year here.
year = 2011;

%%%% Probably don't touch below.


%% Read in options that pertain to the entire tracking package.
%% These settings are all in ../config/options.m
addpath('../../config')
options
save('temp.mat');
OPT = load('temp.mat');
eval('!rm temp.mat')


np = round(OPT.FILTER_STANDARD_DEVIATION);


%% Directories
PROCESSED_DATA_DIR = ['../../data/',CASE_LABEL,'/processed/',...
                      'g',sprintf('%d',FILTER_STANDARD_DEVIATION), '_',...
                       sprintf('%d',ACCUMULATION_PERIOD), ...
                       'h/thresh',num2str(FEATURE_THRESHOLD_VALUE),'/timeclusters'];

OBJECTS_DATA_DIR = ['../../data/',CASE_LABEL,'/processed/',...
                    'g',sprintf('%d',FILTER_STANDARD_DEVIATION), '_',...
                    sprintf('%d',ACCUMULATION_PERIOD), ...
                    'h/thresh',num2str(FEATURE_THRESHOLD_VALUE),'/objects'];

OUTPUT_DATA_DIR = ['../../data/',CASE_LABEL,'/processed/',...
                   'g',sprintf('%d',FILTER_STANDARD_DEVIATION), '_',...
                   sprintf('%d',ACCUMULATION_PERIOD), ...
                   'h/thresh',num2str(FEATURE_THRESHOLD_VALUE),'/masks'];

eval(['!mkdir -p ', OUTPUT_DATA_DIR])


%% Read LPT systems
dir0 = dir([PROCESSED_DATA_DIR,'/TIMECLUSTERS_lpt_',num2str(year),'*.rejoin2.mat']);
fn_in = [PROCESSED_DATA_DIR,'/', dir0(1).name];
disp(fn_in)
G = load(fn_in) ;

for iiii = 2:20
  if isfield(G, ['TIMECLUSTERS', num2str(iiii)])
    eval(['G.TIMECLUSTERS = [G.TIMECLUSTERS, G.TIMECLUSTERS', num2str(iiii),'];'])
  end
end

TIMECLUSTERS=G.TIMECLUSTERS;


for lptid = 1:numel(TIMECLUSTERS);

disp(['Calculating LPT system mask for ID = ', sprintf('%03d',lptid), ' of beginning year ', num2str(year), '.'])

time_with_accumulation = TIMECLUSTERS(lptid).time(1) - OPT.ACCUMULATION_PERIOD / 24.0 : datenum(0,0,0,OPT.DT,0,0) : TIMECLUSTERS(lptid).time(end);

grid_nx = -999;

%% Loop over each time of this LPT.
for iii = 1:numel(TIMECLUSTERS(lptid).time)

  tindx = find(time_with_accumulation == TIMECLUSTERS(lptid).time(iii));
  tindx_accum = tindx - round(OPT.ACCUMULATION_PERIOD / OPT.DT) : tindx;

  for this_objid = [TIMECLUSTERS(lptid).obj(iii).objid]
    %disp(num2str(this_objid))
    OBJ = load_obj_data(OBJECTS_DATA_DIR, this_objid);

    %% Initialize the mask arrays, if they are not set up yet.
    if (grid_nx < -900)

      grid_nx = numel(OBJ.grid.lon);
      grid_ny = numel(OBJ.grid.lat);

      mask_arrays.grid.lon = OBJ.grid.lon; % Pass to output function.
      mask_arrays.grid.lat = OBJ.grid.lat; % Pass to output function.

      mask_arrays.time = time_with_accumulation; % Pass to output function.
      nt = numel(time_with_accumulation);

      %% LPT IDs and Object IDs start at index 1, so set "outside" to be zero.
      mask_arrays.mask_by_objid = zeros(nt, numel(OBJ.grid.lat), numel(OBJ.grid.lon));
      mask_arrays.mask_by_lptid = zeros(nt, numel(OBJ.grid.lat), numel(OBJ.grid.lon));
      mask_arrays.mask_by_lptid_with_filter = zeros(nt, numel(OBJ.grid.lat), numel(OBJ.grid.lon));
      mask_arrays.mask_by_lptid_with_accumulation = zeros(nt, numel(OBJ.grid.lat), numel(OBJ.grid.lon));
      mask_arrays.mask_by_lptid_with_filter_and_accumulation = zeros(nt, numel(OBJ.grid.lat), numel(OBJ.grid.lon));
      
    end

    
    for cccc = 1:numel(OBJ.pixels)  %Sometimes more than one LP Object per time.
      for iiii = 1:numel(OBJ.pixels(cccc).x)

        mask_arrays.mask_by_lptid(tindx, OBJ.pixels(cccc).y(iiii), OBJ.pixels(cccc).x(iiii)) = lptid;
	mask_arrays.mask_by_objid(tindx, OBJ.pixels(cccc).y(iiii), OBJ.pixels(cccc).x(iiii)) = OBJ.id(cccc);
        mask_arrays.mask_by_lptid_with_accumulation(tindx_accum, OBJ.pixels(cccc).y(iiii), OBJ.pixels(cccc).x(iiii)) = lptid;	
	
      end
    end
  end % for loop over CEs for this time of the LPT system (may be more than one!)
  
end % for loop over timecluster entries



disp('Filter width spreading. This may take awhile.')
mask_arrays.mask_by_lptid_with_filter = feature_spread(mask_arrays.mask_by_lptid, np);
mask_arrays.mask_by_lptid_with_filter_and_accumulation = feature_spread(mask_arrays.mask_by_lptid_with_accumulation, np);


%%%% Output

disp('Output:')
nc_out_file = [OUTPUT_DATA_DIR,'/lpt_system_mask_',num2str(year),'_',sprintf('%03d', lptid),'.nc'];
disp(nc_out_file)
lpt_system_mask_output_netcdf(nc_out_file, mask_arrays)

end %loop over LPTID
