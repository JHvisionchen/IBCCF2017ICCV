warning('off','all');
% Add paths
setup_paths();
% Load video information
base_path = '/media/cjh/datasets/tracking/OTB100/';
video = choose_video(base_path);
video_path=[base_path video];
% video_path = '/media/cjh/datasets/tracking/OTB100/Basketball';
[seq, ground_truth] = load_video_info(video_path);
% Run IBCCF
results = run_IBCCF(seq);