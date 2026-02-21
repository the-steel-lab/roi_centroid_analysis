function S = load_roi_data(roi_path, coords_path, roi_list)
% load_roi_data  Load ROI vertex indices and surface coordinates for one
%                subject/hemisphere/task.
%
% PURPOSE:
%   Reads a surface ROI label file and an inflated-surface coordinate file,
%   then extracts vertex indices, XYZ coordinates, and centroids for each
%   ROI in roi_list.
%
% INPUTS:
%   roi_path    : full path to ROI file (two-column text: vertex_idx  roi_num)
%   coords_path : full path to coordinate file (columns: vertex_idx  X  Y  Z)
%   roi_list    : numeric vector of ROI numbers to extract
%
% OUTPUTS:
%   S  : struct with fields:
%     .missing        logical  true if roi_path does not exist
%     .coords_missing logical  true if coords_path does not exist
%     .roi_numbers    vector   unique ROI numbers found in roi_list
%     .vertices{r}   double   0-based vertex indices for ROI number r
%     .coords{r}     Nx3      XYZ coordinates for ROI r
%     .centroid{r}   1x3      mean centroid for ROI r
%
%   Cell arrays are preallocated to max(roi_list) so that ROI number r can
%   be accessed directly as S.vertices{r}, S.coords{r}, S.centroid{r}.
%
% NOTES ON MISSING DATA:
%   - If roi_path is absent, S.missing=true, all cell arrays are empty, and
%     the function returns immediately after a warning.
%   - If coords_path is absent, S.coords_missing=true; vertex indices are
%     loaded but coords and centroids remain empty cells.
%   - The first data row of the ROI file is skipped if it appears to be a
%     header (non-numeric or roi_number not in roi_list).
%   - Vertex indices in the ROI file are 0-based; +1 is added before
%     indexing into the coords matrix.

%% Initialise output struct
max_roi   = max(roi_list);
S.missing        = false;
S.coords_missing = false;
S.roi_numbers    = [];
S.vertices       = cell(max_roi, 1);
S.coords         = cell(max_roi, 1);
S.centroid       = cell(max_roi, 1);

%% Check ROI file existence
if ~exist(roi_path, 'file')
    warning('load_roi_data:missingROI', 'ROI file not found: %s', roi_path);
    S.missing = true;
    return;
end

%% Read ROI file
% Format: two whitespace-delimited columns [vertex_index  roi_number]
% May have a text or numeric header row — detect and skip.
try
    raw = dlmread(roi_path);
catch
    % dlmread failed — try textscan with flexible whitespace
    fid = fopen(roi_path, 'r');
    raw_cell = textscan(fid, '%f %f', 'CommentStyle', '#', ...
                        'CollectOutput', true, 'MultipleDelimsAsOne', true);
    fclose(fid);
    if isempty(raw_cell) || isempty(raw_cell{1})
        warning('load_roi_data:parseError', 'Could not parse ROI file: %s', roi_path);
        S.missing = true;
        return;
    end
    raw = raw_cell{1};
end

if isempty(raw)
    warning('load_roi_data:emptyROI', 'ROI file is empty: %s', roi_path);
    S.missing = true;
    return;
end

% Skip header row if first row's ROI number is not in roi_list
if ~ismember(raw(1,2), roi_list)
    raw = raw(2:end, :);
end

if isempty(raw)
    S.missing = true;
    return;
end

roi_col    = raw(:, 2);   % ROI numbers
vertex_col = raw(:, 1);   % 0-based vertex indices

%% Check coords file existence
if ~exist(coords_path, 'file')
    warning('load_roi_data:missingCoords', 'Coords file not found: %s', coords_path);
    S.coords_missing = true;
    % Still populate vertex index info even without coords
    found_rois = unique(roi_col(ismember(roi_col, roi_list)));
    S.roi_numbers = found_rois(:)';
    for ri = 1:numel(found_rois)
        r = found_rois(ri);
        mask         = roi_col == r;
        S.vertices{r} = vertex_col(mask);
    end
    return;
end

%% Read coords file
% Format: [vertex_index  X  Y  Z]  (columns 2:4 are XYZ)
try
    coords_raw = dlmread(coords_path);
catch
    fid = fopen(coords_path, 'r');
    raw_cell = textscan(fid, '%f %f %f %f', 'CommentStyle', '#', ...
                        'CollectOutput', true, 'MultipleDelimsAsOne', true);
    fclose(fid);
    if isempty(raw_cell) || isempty(raw_cell{1})
        warning('load_roi_data:coordsParseError', ...
                'Could not parse coords file: %s', coords_path);
        S.coords_missing = true;
        return;
    end
    coords_raw = raw_cell{1};
end

% coords_raw rows correspond to vertices (assumed 0-based index in col 1)
% XYZ are columns 2, 3, 4
coords_xyz = coords_raw(:, 2:4);

%% Extract per-ROI vertices, coords, centroids
found_rois    = unique(roi_col(ismember(roi_col, roi_list)));
S.roi_numbers = found_rois(:)';

for ri = 1:numel(found_rois)
    r    = found_rois(ri);
    mask = roi_col == r;

    vtx_0based = vertex_col(mask);          % 0-based indices from file
    vtx_1based = vtx_0based + 1;            % convert to 1-based for MATLAB

    % Guard against out-of-range indices (e.g. header artefacts)
    valid = vtx_1based >= 1 & vtx_1based <= size(coords_xyz, 1);
    if ~all(valid)
        warning('load_roi_data:outOfRange', ...
            'ROI %d has %d vertex indices out of coords range; skipping those.', ...
            r, sum(~valid));
        vtx_0based = vtx_0based(valid);
        vtx_1based = vtx_1based(valid);
    end

    if isempty(vtx_1based)
        S.vertices{r} = [];
        S.coords{r}   = zeros(0, 3);
        S.centroid{r} = [NaN NaN NaN];
        continue;
    end

    roi_coords = coords_xyz(vtx_1based, :);

    S.vertices{r} = vtx_0based;
    S.coords{r}   = roi_coords;
    S.centroid{r} = mean(roi_coords, 1);
end

end
