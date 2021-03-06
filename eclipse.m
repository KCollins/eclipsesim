function eclipse(job_id, make_plot, use_eclipse, ...
                 job_path, out_path, plot_path, sami3_path)
%%----------------------------
%%  Copyright (C) 2017 The Center for Solar-Terrestrial Research at
%%                     the New Jersey Institute of Technology
%%
%%  This program is free software: you can redistribute it and/or modify
%%  it under the terms of the GNU General Public License as published by
%%  the Free Software Foundation, either version 3 of the License, or
%%  (at your option) any later version.
%%
%%  This program is distributed in the hope that it will be useful,
%%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%  GNU General Public License for more details.
%%
%%  You should have received a copy of the GNU General Public License
%%  along with this program.  If not, see <http://www.gnu.org/licenses/>.
%%----------------------------

    global SPEED_OF_LIGHT
    global ELEV_STEP
    global NUM_HOPS
    global ELEVS
    global TX_POWER
    global GAIN_TX_DB
    global GAIN_RX_DB
    global R12
    global CALC_DOPPLER
    global CALC_IRREGS
    global KP
    global MAX_RANGE
    global NUM_RANGES
    global TOL
    global RANGE_INC
    global START_HEIGHT
    global HEIGHT_INC
    global NUM_HEIGHTS
    global START_TIMESTAMP

    SPEED_OF_LIGHT  = 2.99792458e8;
    ELEV_STEP       = 0.5;
    NUM_HOPS        = 3;
    ELEVS           = [5:ELEV_STEP:60];
    TX_POWER        = 1;
    GAIN_TX_DB      = 1;
    GAIN_RX_DB      = 1;
    R12             = -1;
    CALC_DOPPLER    = 0;
    CALC_IRREGS     = 0;
    KP              = 0;
    MAX_RANGE       = 10000;
    NUM_RANGES      = 201;
    TOL             = 1e-7;
    RANGE_INC       = MAX_RANGE ./ (NUM_RANGES - 1);
    START_HEIGHT    = 0;
    HEIGHT_INC      = 3;
    NUM_HEIGHTS     = 200;
    START_TIMESTAMP = datenum('21-Aug-2017 16:00:00');
    
    if use_eclipse == 0
        ecl_str     = 'base';
        ecl_title   = 'Base';
    else
        ecl_str     = 'eclipse';
        ecl_title   = 'Eclipse';
    end
    
    PLT_PATH = strcat(plot_path,ecl_str,'/');
    OUT_PATH = strcat(out_path,ecl_str,'/');


    % Get the timestamp of the current moment.
    timestamp = addtodate(START_TIMESTAMP, (job_id * 3), 'minute');
    UT = datevec(timestamp);
    UT = UT(1:5)

    disp('Loading ionosphere...');

    load(strcat(sami3_path, 'grid.mat'));
    load(strcat(sami3_path, 'data_', num2str(job_id, '%04u'), '.mat'));

    if use_eclipse ~= 0
        interpolator = scatteredInterpolant(double(grid_lats(:)), ...
                                            double(grid_lons(:)), ...
                                            double(grid_heights(:)), ...
                                            double(eclipse_data(:)), ...
                                            'natural');
    else
        interpolator = scatteredInterpolant(double(grid_lats(:)), ...
                                            double(grid_lons(:)), ...
                                            double(grid_heights(:)), ...
                                            double(base_data(:)), ...
                                            'natural');
    end

    disp('Done.');

    irreg = zeros(4, NUM_RANGES);

    timestamp_str = datestr(timestamp, 'yyyy-mm-dd HH:MM:SS');

    job_file        = fopen(strcat(job_path, timestamp_str, '.csv'), 'r');
    out_file        = fopen(strcat(OUT_PATH, 'simulated_',ecl_str,'_', timestamp_str, '.csv'), 'w');

    % Write header
    fprintf(out_file, ['tx_call,' ...
                       'rx_call,' ...
                       'tx_lat,' ...
                       'tx_lon,' ...
                       'rx_lat,' ...
                       'rx_lon,' ...
                       'freq,' ...
                       'srch_rd_lat,' ...
                       'srch_rd_lon,' ...
                       'srch_rd_ground_range,' ...
                       'srch_rd_group_range,' ...
                       'srch_rd_phase_path,' ...
                       'srch_rd_geometric_path_length,' ...
                       'srch_rd_initial_elev,' ...
                       'srch_rd_final_elev,' ...
                       'srch_rd_apogee,' ...
                       'srch_rd_gnd_rng_to_apogee,' ...
                       'srch_rd_plasma_freq_at_apogee,' ...
                       'srch_rd_virtual_height,' ...
                       'srch_rd_effective_range,' ...
                       'srch_rd_deviative_absorption,' ...
                       'srch_rd_TEC_path,' ...
                       'srch_rd_Doppler_shift,' ...
                       'srch_rd_Doppler_spread,' ...
                       'srch_rd_FAI_backscatter_loss,' ...
                       'srch_rd_frequency,' ...
                       'srch_rd_nhops_attempted,' ...
                       'srch_rd_hop_idx,' ...
                       'srch_rd_apogee_lat,' ...
                       'srch_rd_apogee_lon' ...
                       '\n']);
                   
    % Read the header line of the job file.
    fgets(job_file);

    while ~feof(job_file)
        data = fgets(job_file);
        data = strsplit(data, ',');

        % Pull all the relevant values from the current CSV row.
        rx_call = cell2mat(data(1));
        tx_call = cell2mat(data(2));
        freq    = str2num(cell2mat(data(3)));
        rx_lat  = str2num(cell2mat(data(4)));
        rx_lon  = str2num(cell2mat(data(5)));
        tx_lat  = str2num(cell2mat(data(6)));
        tx_lon  = str2num(cell2mat(data(7)));

        % Just something to show we're still working.
        disp([tx_call, ' to ', rx_call, ' (', num2str(freq), ' MHz)']);

        % Calculate azimuth and range.
        [range, azimuth] = latlon2raz(rx_lat, rx_lon, tx_lat, tx_lon);
        range = range / 1000.;    % Convert from m to km

        slice_params = [tx_lat tx_lon rx_lat rx_lon ...
                        NUM_RANGES RANGE_INC ...
                        START_HEIGHT HEIGHT_INC NUM_HEIGHTS];

        % Create a 2-D slice.
        iono_en_grid_2d = create_2d_slice(interpolator, slice_params);
        iono_pf_grid_2d = real((iono_en_grid_2d * 80.6164e-6) .^ 0.5);

        slice_size        = size(iono_en_grid_2d);
        collision_freq_2d = zeros(slice_size(1), NUM_RANGES);

        freqs = freq .* ones(size(ELEVS));

        % Run the raytracer.
        [ray_data, ray_path_data] = ...
            raytrace_2d(tx_lat, tx_lon, ELEVS, azimuth, freqs, ...
                        NUM_HOPS, TOL, CALC_IRREGS, iono_en_grid_2d, ...
                        iono_en_grid_2d, collision_freq_2d, ...
                        START_HEIGHT, HEIGHT_INC, RANGE_INC, irreg);
        
        out_all_fname   = strcat(OUT_PATH, 'all_',rx_call,'_',tx_call,'_',ecl_str,'_', timestamp_str, '.csv');    
        write_ray_data(rx_call,rx_lat,rx_lon,tx_call,tx_lat,tx_lon,freq,ray_data,out_all_fname)
                    
        % Attempt to identify rays that are hitting the receiver
        num_elevs = length(ELEVS);

        srch_gnd_range = zeros(num_elevs, NUM_HOPS);
        srch_grp_range = zeros(num_elevs, NUM_HOPS);
        srch_labels    = zeros(num_elevs, NUM_HOPS);
        srch_ray_good  = 0;

        for elev_idx = 1:num_elevs
            curr_ray_data = ray_data(elev_idx);
            
            for hop_idx = 1:curr_ray_data.nhops_attempted
                srch_gnd_range(elev_idx, hop_idx) = ...
                    curr_ray_data.ground_range(hop_idx);
                srch_grp_range(elev_idx, hop_idx) = ...
                    curr_ray_data.group_range(hop_idx);
                srch_labels(elev_idx, hop_idx) = ...
                    curr_ray_data.ray_label(hop_idx);
            end
        end

        [srch_ray_good, srch_frequency, srch_elevation, srch_group_range, ...
         srch_deviative_absorption, srch_D_Oabsorp, srch_D_Xabsorp, ...
         srch_fs_loss, srch_effective_range, srch_phase_path, ...
         srch_ray_apogee, srch_ray_apogee_gndr, srch_plasfrq_at_apogee, ...
         srch_ray_hops, srch_del_freq_O, srch_del_freq_X, srch_ray_data, ...
         srch_ray_path_data] = find_good_rays(srch_labels, srch_gnd_range, ...
                                              srch_grp_range, range, freq, ...
                                              tx_lat, tx_lon, azimuth, UT);
        if make_plot ~= 0
            plottable = 1;

            for ray_idx = 1:length(ray_path_data)
                if isempty(ray_path_data(ray_idx).ground_range)
                    continue
                end

                if isempty(ray_path_data(ray_idx).height)
                    continue
                end

                if length(ray_path_data(ray_idx).ground_range) ~= ...
                        length(unique(ray_path_data(ray_idx).ground_range))
                    plottable = 0
                end
            end

            %%
            %% Plot Raytrace
            %%
            if plottable ~= 0
                plot_raytrace(tx_lat, tx_lon, azimuth, START_HEIGHT, ...
                              HEIGHT_INC, iono_pf_grid_2d, ...
                              ray_path_data, srch_ray_path_data, UT);
            else
                plot_raytrace(tx_lat, tx_lon, azimuth, START_HEIGHT, ...
                              HEIGHT_INC, iono_pf_grid_2d, ...
                              ray_path_data, 0, UT);                
            end
            
            % TODO: Sanitize the callsigns to make them filesystem friendly.
            disp(PLT_PATH)
            plot_fname = strcat(PLT_PATH, timestamp_str, '-', ...
                                  tx_call, '-', rx_call, '_', ...
                                  num2str(freq), '_',ecl_str, ...
                                  '.png');
            plot_title = {strcat(ecl_title," ",timestamp_str); ... 
                          strcat("TX: ",tx_call, " Rx: ", rx_call," ", num2str(freq), " MHz")};
            suptitle(plot_title);
            print('-dpng', plot_fname);
        end
                                          
        if srch_ray_good ~= 0
            disp('Good ray found.');
            
            srch_rd_points = 0;
            srch_num_elevs = length(srch_ray_data);

            for idx = 1:srch_num_elevs
                srch_rd_points = srch_rd_points + length(srch_ray_data(idx).lat);
            end

            % Create index vector for ray segments
            srch_rd_id = zeros(1, srch_rd_points);
            start_idx  = 1;

            for idx = 1:srch_num_elevs
                n = length(srch_ray_data(idx).lat);
                end_idx = start_idx + n - 1;
                srch_rd_id(start_idx:end_idx) = idx;
                start_idx = end_idx + 1;
            end

            srch_fieldnames = fieldnames(srch_ray_data);

            for idx = 1:length(srch_fieldnames)
                expr = strcat('srch_rd_', srch_fieldnames(idx), ...
                              ' = zeros(1,', num2str(srch_rd_points), ');');
                eval(expr{1});
            end

            start_idx = 1;

            for idx = 1:srch_num_elevs
                n       = length(srch_ray_data(idx).lat);
                end_idx = start_idx + n - 1;

                for idx2 = 1:length(srch_fieldnames)
                    if ~strcmp(srch_fieldnames(idx2), 'FAI_backscatter_loss')
                        lhs = strcat('srch_rd_', srch_fieldnames(idx2), ...
                                    '(', num2str(start_idx), ':', ...
                                    num2str(end_idx), ')');
                        rhs = strcat('srch_ray_data(', num2str(idx), ').', ...
                                     srch_fieldnames(idx2));
                        expr = strcat(lhs{1}, '=', rhs{1}, ';');
                        eval(expr);
                    end
                end

                start_idx = end_idx + 1;
            end
            
            % TODO: Power computations
            for i = 1:length(srch_rd_lat)
                % Calculate apogee coordinates
                [rng, azm] = latlon2raz(srch_rd_lat(i), srch_rd_lon(i), tx_lat, tx_lon);
                
                [apogee_lat, apogee_lon] = raz2latlon(srch_rd_ground_range(i) * 1000, ...
                                                      azm, tx_lat, tx_lon);
                
                fprintf(out_file, '%s,%s,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f\n', ...
                        tx_call, ...
                        rx_call, ...
                        tx_lat, ...
                        tx_lon, ...
                        rx_lat, ...
                        rx_lon, ...
                        freq, ...
                        srch_rd_lat(i), ...
                        srch_rd_lon(i), ...
                        srch_rd_ground_range(i), ...
                        srch_rd_group_range(i), ...
                        srch_rd_phase_path(i), ...
                        srch_rd_geometric_path_length(i), ...
                        srch_rd_initial_elev(i), ...
                        srch_rd_final_elev(i), ...
                        srch_rd_apogee(i), ...
                        srch_rd_gnd_rng_to_apogee(i), ...
                        srch_rd_plasma_freq_at_apogee(i), ...
                        srch_rd_virtual_height(i), ...
                        srch_rd_effective_range(i), ...
                        srch_rd_deviative_absorption(i), ...
                        srch_rd_TEC_path(i), ...
                        srch_rd_Doppler_shift(i), ...
                        srch_rd_Doppler_spread(i), ...
                        srch_rd_FAI_backscatter_loss(i), ...
                        srch_rd_frequency(i), ...
                        srch_rd_nhops_attempted(i), ...
                        i, ...
                        apogee_lat, ...
                        apogee_lon);
            end
        end
    end
end
