function [model_xf, model_xf_border, model_alphaf, model_alphaf_border] = update_model(feat, feat_border,...
            yf, model_xf, model_xf_border, model_alphaf, model_alphaf_border, init_target_sz, opts)
        
% Initialize the parameters    
numLayers = length(feat);
interp_factor = opts.interp_factor;
lambda = opts.lambda;
mu = opts.mu;
frame = opts.frame;
cell_size = opts.cell_size;
reshape_mode = opts.reshape_mode;
feat_size_border = opts.feat_size_border;
yf_border = opts.yf_border;
update_time_stamp = opts.update_time_stamp;
max_init_value = opts.max_init_value;
scale_factor = opts.scale_factor;

% Initialize the related variables for alternate update
max_iteration = 1;
[P_center, G_center, F_center] = deal(cell(numLayers, 1));
[P_border, G_border, F_border] = deal(cell(numLayers, 4));
[alphaf, xf] = deal(cell(1, numLayers));
[alphaf_border, xf_border] = deal(cell(numLayers, 4));
common_region_sz = floor(init_target_sz / cell_size);% the common region size is defined as the initial target size in the first frame
epilson = 1e-8;
gamma_0 = min(max_init_value, 1e-2 / (mu + epilson));
rho_0 = min(max_init_value, 1e-2 / (mu + epilson));

for ii = 1 : numLayers
    [P_center{ii},G_center{ii}] = deal(zeros(size(feat{ii})));
    for i = 1 : size(P_border,2)
        [P_border{ii,i}, G_border{ii,i}] = deal(zeros(size(feat_border{ii, i})));
    end
end

% ================================================================================
% ADMM algorithm 
% ================================================================================
for ii = 1 : numLayers    
    % compute standard correaltion filters for CCF
    [F_center{ii}, alphaf{ii}, xf{ii}] = compute_2D_CF(feat{ii}, yf, lambda);
    if(frame == 1 || mod(frame, update_time_stamp) == 0)
        filter_sz = size(feat{ii});
        iter = 1;
        while iter <= max_iteration
            % Keep F_center fixed and solve F_border
            tmp = real(ifft2(F_center{ii}));
            [crop_range_w, crop_range_h] = get_common_region(filter_sz(1:2), [], common_region_sz, 0);
            crop_region = tmp(crop_range_w, crop_range_h,:);
            
            for i = 1:size(P_border,2)
                [F_border{ii,i}, alphaf_border{ii,i}, xf_border{ii,i}] = ADMM(feat_border{ii,i}, gamma_0, scale_factor, yf_border{i}, G_border{ii,i}, P_border{ii,i}, crop_region, common_region_sz, feat_size_border,opts,i);
            end
            
            % Keep F_border fixed and solve F_center
            crop_regions = cell(size(P_border,2), 1);
            for i = 1: size(P_border,2)
                feat_size = feat_size_border(i);
                tmp = real(ifft2(reshape_features(F_border{ii,i}, feat_size{1}, reshape_mode(i), '1Dto2D')));
                [crop_range_w, crop_range_h] = get_common_region(filter_sz(1:2), feat_size_border, common_region_sz, i);
                crop_regions{i} = tmp(crop_range_w, crop_range_h,:);
            end
            
             [F_center{ii}, alphaf{ii}, xf{ii}] = ADMM(feat{ii}, rho_0, scale_factor, yf, G_center{ii}, P_center{ii}, crop_regions, common_region_sz, feat_size_border, opts, 0);
                        
            iter = iter + 1;
        end
    end
end

% Model initialization or update
if frame == 1
    for ii=1:numLayers       
        model_alphaf{ii} = alphaf{ii};
        model_xf{ii} = xf{ii};         
        
        for i = 1: size(alphaf_border, 2)
            model_alphaf_border{ii,i} = alphaf_border{ii,i};
            model_xf_border{ii,i} = xf_border{ii,i};          
        end    
    end
else
    % Online model update using learning rate interp_factor
    for ii=1:numLayers
        model_alphaf{ii} = (1 - interp_factor) * model_alphaf{ii} + interp_factor * alphaf{ii};
        model_xf{ii}     = (1 - interp_factor) * model_xf{ii}     + interp_factor * xf{ii};
        if(mod(frame, update_time_stamp) == 0)
            for i = 1: size(alphaf_border,4)
                model_alphaf_border{ii,i} = (1 - interp_factor) * model_alphaf_border{ii,i} + interp_factor * alphaf_border{ii,i};
                model_xf_border{ii,i} = (1 - interp_factor) * model_xf_border{ii,i} + interp_factor * xf_border{ii,i};
            end
        end
    end
end
end
