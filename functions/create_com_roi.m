function out_paths = create_com_roi(roi_path, coords_path, roi_list, output_dir, n_vertices)
% create_com_roi  Create a center-of-mass sub-ROI from an existing surface ROI.
%
% For each ROI in roi_list, selects the N vertices closest (Euclidean distance
% in inflated-surface space) to the ROI's center of mass and writes them to a
% new .1D.roi file. Useful for creating spatially compact, comparable sub-ROIs
% across subjects and tasks.
%
% Inputs:
%   roi_path    - path to input .1D.roi file  [vertex_index  roi_number]
%   coords_path - path to coordinate file     [vertex_index  X  Y  Z]
%   roi_list    - vector of ROI numbers to process
%   output_dir  - directory to write output files (created if needed)
%   n_vertices  - number of closest-to-COM vertices to keep (default: 300)
%
% Outputs:
%   out_paths   - cell array of output file paths ('' for skipped ROIs)
%
% Output filename format:
%   <roi_number>.COM.<n_vertices>.<hemi>.1D.roi
%   where hemi is parsed from roi_path ('lh' or 'rh')
%
% Notes on missing data:
%   - If roi_path or coords_path does not exist, a warning is issued and
%     out_paths is returned as a cell array of empty strings.
%   - If a ROI has fewer vertices than n_vertices, a warning is issued and
%     all available vertices are used.
%   - Per-ROI errors are caught and reported as warnings; processing continues
%     to the next ROI.

%% Named constants
DEFAULT_N_VERTICES = 300;

%% Handle default argument
if nargin < 5 || isempty(n_vertices)
    n_vertices = DEFAULT_N_VERTICES;
end

%% Initialise output
out_paths = repmat({''}, numel(roi_list), 1);

%% Check file existence
if ~exist(roi_path, 'file')
    warning('create_com_roi:missingROI', 'ROI file not found: %s', roi_path);
    return;
end

if ~exist(coords_path, 'file')
    warning('create_com_roi:missingCoords', 'Coords file not found: %s', coords_path);
    return;
end

%% Parse hemisphere from roi_path filename
hemi_match = regexpi(roi_path, '(lh|rh)', 'match', 'once');
if isempty(hemi_match)
    hemi = 'unknown';
else
    hemi = lower(hemi_match);
end

%% Create output directory if needed
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% Load coordinate file
% Format: [vertex_index  X  Y  Z]  — columns 2:4 are XYZ
% Row (i+1) corresponds to 0-based vertex index i.
try
    coords_raw = dlmread(coords_path);
catch
    fid = fopen(coords_path, 'r');
    raw_cell = textscan(fid, '%f %f %f %f', 'CommentStyle', '#', ...
                        'CollectOutput', true, 'MultipleDelimsAsOne', true);
    fclose(fid);
    if isempty(raw_cell) || isempty(raw_cell{1})
        warning('create_com_roi:coordsParseError', ...
                'Could not parse coords file: %s', coords_path);
        return;
    end
    coords_raw = raw_cell{1};
end

coords_xyz = coords_raw(:, 2:4);   % XYZ matrix; 1-based row = 0-based vertex + 1

%% Load ROI file
% Format: [vertex_index  roi_number]
% Header row detection: skip row 1 if its roi_number is not in roi_list.
try
    raw = dlmread(roi_path);
catch
    fid = fopen(roi_path, 'r');
    raw_cell = textscan(fid, '%f %f', 'CommentStyle', '#', ...
                        'CollectOutput', true, 'MultipleDelimsAsOne', true);
    fclose(fid);
    if isempty(raw_cell) || isempty(raw_cell{1})
        warning('create_com_roi:roiParseError', ...
                'Could not parse ROI file: %s', roi_path);
        return;
    end
    raw = raw_cell{1};
end

if isempty(raw)
    warning('create_com_roi:emptyROI', 'ROI file is empty: %s', roi_path);
    return;
end

% Skip header row using the same rule as load_roi_data.m
if ~ismember(raw(1,2), roi_list)
    raw = raw(2:end, :);
end

if isempty(raw)
    warning('create_com_roi:noData', 'No data rows in ROI file: %s', roi_path);
    return;
end

vertex_col = raw(:, 1);   % 0-based vertex indices
roi_col    = raw(:, 2);   % ROI numbers

%% Process each ROI
for ri = 1:numel(roi_list)
    r = roi_list(ri);

    try
        % Extract vertices belonging to this ROI
        mask       = roi_col == r;
        vtx_0based = vertex_col(mask);

        if isempty(vtx_0based)
            % ROI not present in this file — leave out_paths{ri} = ''
            continue;
        end

        % Convert to 1-based MATLAB indices
        vtx_1based = vtx_0based + 1;

        % Guard against out-of-range indices
        valid = vtx_1based >= 1 & vtx_1based <= size(coords_xyz, 1);
        if ~all(valid)
            warning('create_com_roi:outOfRange', ...
                'ROI %d: %d vertex indices are out of coords range; skipping those.', ...
                r, sum(~valid));
            vtx_0based = vtx_0based(valid);
            vtx_1based = vtx_1based(valid);
        end

        if isempty(vtx_1based)
            continue;
        end

        roi_coords = coords_xyz(vtx_1based, :);   % Nv x 3

        % Compute center of mass (mean XYZ across all vertices in ROI)
        centroid = mean(roi_coords, 1);   % 1x3

        % Euclidean distance from each vertex to the centroid
        diffs = roi_coords - repmat(centroid, size(roi_coords, 1), 1);
        dists = sqrt(sum(diffs .^ 2, 2));   % Nv x 1

        % Sort ascending by distance; take the n_vertices closest
        [~, sort_idx] = sort(dists, 'ascend');

        n_available = numel(vtx_0based);
        if n_available < n_vertices
            warning('create_com_roi:tooFewVertices', ...
                'ROI %d in %s has only %d vertices (< requested %d). Using all.', ...
                r, roi_path, n_available, n_vertices);
            n_keep = n_available;
        else
            n_keep = n_vertices;
        end

        selected_sort_idx  = sort_idx(1:n_keep);
        vtx_selected_0based = vtx_0based(selected_sort_idx);

        % Re-sort selected vertices by 0-based vertex index ascending
        vtx_selected_0based = sort(vtx_selected_0based, 'ascend');

        % Build output filename and path
        out_file = sprintf('%d.COM.%d.%s.1D.roi', r, n_vertices, hemi);
        out_path = fullfile(output_dir, out_file);

        fprintf('  Writing COM ROI: %s\n', out_file);

        % Write output file
        % Format:
        %   Header row : <n_keep>  <roi_number>
        %   Data rows  : <vertex_index_0based>  <roi_number>
        fid = fopen(out_path, 'w');
        if fid == -1
            error('create_com_roi:openFailed', 'Cannot open for writing: %s', out_path);
        end

        % Header row
        fprintf(fid, '%d\t%d\n', n_keep, r);

        % Data rows
        for vi = 1:n_keep
            fprintf(fid, '%d\t%d\n', vtx_selected_0based(vi), r);
        end

        fclose(fid);

        out_paths{ri} = out_path;

    catch ME
        warning('create_com_roi:roiError', ...
            'Failed to process ROI %d from %s: %s', r, roi_path, ME.message);
    end

end % roi_list loop

end
