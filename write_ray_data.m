function write_ray_data(rx_call,rx_lat,rx_lon,...
                        tx_call,tx_lat,tx_lon,...
                        freq,ray_data,fname)
                                           
% load("ray_data_sample.mat")
% 
% rx_call = "WE9V";
% tx_call = "AA2MF";
% 
% rx_lat  =  42.5625;
% rx_lon  = -88.00417;
% tx_lat  =  27.8125;
% tx_lon  = -82.7917;
% 
% freq    =  14.030;
% fname   = 'test_rdall.csv'

out_all_file    = fopen(fname, 'w');

% Write header
fprintf(out_all_file, ['tx_call,' ...
                   'rx_call,' ...
                   'tx_lat,' ...
                   'tx_lon,' ...
                   'rx_lat,' ...
                   'rx_lon,' ...
                   'freq,' ...
                   'rdall_lat,' ...
                   'rdall_lon,' ...
                   'rdall_ground_range,' ...
                   'rdall_group_range,' ...
                   'rdall_phase_path,' ...
                   'rdall_geometric_path_length,' ...
                   'rdall_initial_elev,' ...
                   'rdall_final_elev,' ...
                   'rdall_apogee,' ...
                   'rdall_gnd_rng_to_apogee,' ...
                   'rdall_plasma_freq_at_apogee,' ...
                   'rdall_virtual_height,' ...
                   'rdall_effective_range,' ...
                   'rdall_deviative_absorption,' ...
                   'rdall_TEC_path,' ...
                   'rdall_Doppler_shift,' ...
                   'rdall_Doppler_spread,' ...
                   'rdall_frequency,' ...
                   'rdall_nhops_attempted,' ...
                   'rdall_hop_idx,' ...
                   'rdall_apogee_lat,' ...
                   'rdall_apogee_lon' ...
                   '\n']);
                   
rdall_lat                   = [];
rdall_lon                   = [];
rdall_ground_range          = [];
rdall_group_range           = [];
rdall_phase_path            = [];
rdall_geometric_path_length = [];
rdall_initial_elev          = [];
rdall_final_elev            = [];
rdall_apogee                = [];
rdall_gnd_rng_to_apogee     = [];
rdall_plasma_freq_at_apogee = [];
rdall_virtual_height        = [];
rdall_effective_range       = [];
rdall_deviative_absorption  = [];
rdall_TEC_path              = [];
rdall_Doppler_shift         = [];
rdall_Doppler_spread        = [];
rdall_frequency             = [];
rdall_nhops_attempted       = [];
rdall_hop_idx               = [];
rdall_apogee_lat            = [];
rdall_apogee_lon            = [];                  

for inx = 1:length(ray_data)
    this_ray = ray_data(inx);
    for hop_inx = 1:length(this_ray.lat)
        lat                     = this_ray.lat(hop_inx);
        lon                     = this_ray.lon(hop_inx);
        ground_range            = this_ray.ground_range(hop_inx);
        group_range             = this_ray.group_range(hop_inx);
        phase_path              = this_ray.phase_path(hop_inx);
        geometric_path_length   = this_ray.geometric_path_length(hop_inx);
        initial_elev            = this_ray.initial_elev(hop_inx);
        final_elev              = this_ray.final_elev(hop_inx);
        apogee                  = this_ray.apogee(hop_inx);
        gnd_rng_to_apogee       = this_ray.gnd_rng_to_apogee(hop_inx);
        plasma_freq_at_apogee   = this_ray.plasma_freq_at_apogee(hop_inx);
        virtual_height          = this_ray.virtual_height(hop_inx);
        effective_range         = this_ray.effective_range(hop_inx);
        deviative_absorption    = this_ray.deviative_absorption(hop_inx);
        TEC_path                = this_ray.TEC_path(hop_inx);
        Doppler_shift           = this_ray.Doppler_shift(hop_inx);
        Doppler_spread          = this_ray.Doppler_spread(hop_inx);
        frequency               = this_ray.frequency;
        nhops_attempted         = this_ray.nhops_attempted;
        hop_idx                 = hop_inx;
        
        [rng, azm] = latlon2raz(lat, lon, tx_lat, tx_lon);
        [apogee_lat, apogee_lon] = raz2latlon(ground_range * 1000, ...
                                                      azm, tx_lat, tx_lon);
                                                  
        rdall_lat                   = [rdall_lat lat];
        rdall_lon                   = [rdall_lon lon];
        rdall_ground_range          = [rdall_ground_range ground_range];
        rdall_group_range           = [rdall_group_range group_range];
        rdall_phase_path            = [rdall_phase_path phase_path];
        rdall_geometric_path_length = [rdall_geometric_path_length geometric_path_length];
        rdall_initial_elev          = [rdall_initial_elev initial_elev];
        rdall_final_elev            = [rdall_final_elev final_elev];
        rdall_apogee                = [rdall_apogee apogee];
        rdall_gnd_rng_to_apogee     = [rdall_gnd_rng_to_apogee gnd_rng_to_apogee];
        rdall_plasma_freq_at_apogee = [rdall_plasma_freq_at_apogee plasma_freq_at_apogee];
        rdall_virtual_height        = [rdall_virtual_height virtual_height];
        rdall_effective_range       = [rdall_effective_range effective_range];
        rdall_deviative_absorption  = [rdall_deviative_absorption deviative_absorption];
        rdall_TEC_path              = [rdall_TEC_path TEC_path];
        rdall_Doppler_shift         = [rdall_Doppler_shift Doppler_shift];
        rdall_Doppler_spread        = [rdall_Doppler_spread Doppler_spread];
        rdall_frequency             = [rdall_frequency frequency];
        rdall_nhops_attempted       = [rdall_nhops_attempted nhops_attempted];
        rdall_hop_idx               = [rdall_hop_idx hop_idx];
        rdall_apogee_lat            = [rdall_apogee_lat apogee_lat];
        rdall_apogee_lon            = [rdall_apogee_lon apogee_lon];                                           
    end
    disp(this_ray)
end

 % Output Information from All Rays
for i = 1:length(rdall_lat)
    % Calculate apogee coordinates
    [rng, azm] = latlon2raz(rdall_lat(i), rdall_lon(i), tx_lat, tx_lon);

    [apogee_lat, apogee_lon] = raz2latlon(rdall_ground_range(i) * 1000, ...
                                          azm, tx_lat, tx_lon);

    fprintf(out_all_file, '%s,%s,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f\n', ...
            tx_call, ...
            rx_call, ...
            tx_lat, ...
            tx_lon, ...
            rx_lat, ...
            rx_lon, ...
            freq, ...
            rdall_lat(i), ...
            rdall_lon(i), ...
            rdall_ground_range(i), ...
            rdall_group_range(i), ...
            rdall_phase_path(i), ...
            rdall_geometric_path_length(i), ...
            rdall_initial_elev(i), ...
            rdall_final_elev(i), ...
            rdall_apogee(i), ...
            rdall_gnd_rng_to_apogee(i), ...
            rdall_plasma_freq_at_apogee(i), ...
            rdall_virtual_height(i), ...
            rdall_effective_range(i), ...
            rdall_deviative_absorption(i), ...
            rdall_TEC_path(i), ...
            rdall_Doppler_shift(i), ...
            rdall_Doppler_spread(i), ...
            rdall_frequency(i), ...
            rdall_nhops_attempted(i), ...
            rdall_hop_idx(i), ...
            apogee_lat, ...
            apogee_lon);
end

fclose(out_all_file);