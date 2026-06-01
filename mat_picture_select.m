mat_picture_select1();
function mat_picture_select1()
% 多MAT文件绘图工具 - 支持全局覆盖（无面板），修复固定文件筛选问题
% 新增：全局"默认X轴"选项，勾选后所有曲线使用索引作为X轴
% 新增：对数坐标轴选项（线性 / X轴对数 / Y轴对数 / 双对数）
% 新增：全局线宽 + 网格开关
% 新增：多配置文件管理（支持按 前缀_图表标题 保存/加载/删除）
% 新增：同步X轴变量 / 同步Y轴变量（可选）
% 新增：交换X/Y变量按钮
% 新增：保存配置时自动将文件路径转为相对路径（相对于本脚本所在目录），
%       加载时自动恢复绝对路径，实现不同用户间配置共享。
% 修复：加载配置后，点击"选择MAT文件"时，对话框自动定位到第一个MAT文件所在文件夹（恒生效）。
% 新增：添加MAT文件时采用追加模式（不清除已有文件）
% 新增：清空文件按钮（无需确认直接清空）
% 新增：每个文件旁增加"删除"按钮，支持删除指定文件（删除后自动重置筛选）
% 新增：子图模式选择（1x1 / 1x2 / 2x2），每个文件可指定子图编号（支持多子图）
% 新增：坐标轴范围控制（可分别设置X/Y轴显示范围，可启用/禁用，默认禁用）

% ==================== 配置文件名前缀 ====================
CONFIG_PREFIX = 'multiplot_';

script_dir = fileparts(mfilename('fullpath'));

fig = uifigure('Name', '多文件绘图工具 (全局覆盖+子图)', ...
    'Position', [0, 0, 1020, 780]);  % 高度不变，容纳控件

% =============== 顶部控件区 ================
btn_file = uibutton(fig, 'push', 'Text', '添加 MAT 文件', ...
    'Position', [30, 710, 120, 32], 'ButtonPushedFcn', @(btn, ~) add_files());
btn_clear = uibutton(fig, 'push', 'Text', '清空文件', ...
    'Position', [160, 710, 80, 32], 'ButtonPushedFcn', @(btn, ~) clear_all_files());
txt_files = uitextarea(fig, 'Position', [250, 695, 730, 50], ...
    'Editable', 'off', 'FontSize', 11, 'WordWrap', 'on');

% ---------- 子图模式选择（取代行列输入）----------
uilabel(fig, 'Text', '子图模式:', 'Position', [30, 665, 60, 22]);
subplot_mode = uidropdown(fig, 'Items', {'1x1', '1x2', '2x2'}, ...
    'Position', [95, 662, 80, 28], 'Value', '1x1', 'Tooltip', '选择子图布局');

% 标签和编辑框位置下移（与原行列输入时一致）
uilabel(fig, 'Text', 'X轴标签:', 'Position', [30, 630, 60, 22]);
edit_xlabel = uieditfield(fig, 'Position', [100, 630, 180, 26], 'Value', '信噪比');
uilabel(fig, 'Text', 'Y轴标签:', 'Position', [320, 630, 60, 22]);
edit_ylabel = uieditfield(fig, 'Position', [390, 630, 180, 26], 'Value', '误码率');

uilabel(fig, 'Text', '图表标题:', 'Position', [30, 590, 60, 22]);
edit_title = uieditfield(fig, 'Position', [100, 590, 470, 26], 'Value', '多文件对比图');

% 关键词筛选区域
uilabel(fig, 'Text', '关键词筛选 (空格分隔):', 'Position', [600, 590, 150, 22]);
edit_keyword = uieditfield(fig, 'Position', [755, 590, 100, 26]);
btn_filter = uibutton(fig, 'push', 'Text', '筛选', ...
    'Position', [860, 590, 50, 28], 'ButtonPushedFcn', @(btn, ~) apply_filter());
btn_reset_filter = uibutton(fig, 'push', 'Text', '重置', ...
    'Position', [915, 590, 50, 28], 'ButtonPushedFcn', @(btn, ~) reset_filter());

% =============== 全局覆盖控件 ================
base_y = 550;
chk_global_type = uicheckbox(fig, 'Text', '启用', ...
    'Position', [30, base_y, 55, 25], 'Value', false);
global_type = uidropdown(fig, 'Items', {'曲线', '竖线'}, ...
    'Position', [90, base_y+2, 70, 28], 'Value', '曲线');
uilabel(fig, 'Text', '类型', 'Position', [170, base_y+5, 35, 22]);

chk_global_linestyle = uicheckbox(fig, 'Text', '启用', ...
    'Position', [230, base_y, 55, 25], 'Value', false);
global_linestyle = uidropdown(fig, 'Items', {'-', '--', ':', '-.'}, ...
    'Position', [290, base_y+2, 70, 28], 'Value', '-');
uilabel(fig, 'Text', '线型', 'Position', [370, base_y+5, 35, 22]);

chk_global_marker = uicheckbox(fig, 'Text', '启用', ...
    'Position', [430, base_y, 55, 25], 'Value', false);
global_marker = uidropdown(fig, 'Items', ...
    {'none','o','+','*','.','x','s','d','^','v','>','<','p','h'}, ...
    'Position', [490, base_y+2, 70, 28], 'Value', 'none');
uilabel(fig, 'Text', '标记', 'Position', [570, base_y+5, 35, 22]);

chk_default_x = uicheckbox(fig, 'Text', '默认X轴 (索引)', ...
    'Position', [620, base_y+2, 120, 25], 'Value', false);

uilabel(fig, 'Text', '坐标轴:', 'Position', [750, base_y+5, 50, 22]);
axis_mode = uidropdown(fig, 'Items', {'线性', 'X轴对数', 'Y轴对数', '双对数'}, ...
    'Position', [800, base_y+2, 110, 28], 'Value', '线性');

% =============== 线宽和网格 + 坐标轴范围控制 ===============
new_y = base_y - 45;
chk_global_linewidth = uicheckbox(fig, 'Text', '启用', ...
    'Position', [30, new_y, 55, 25], 'Value', false);
edit_linewidth = uieditfield(fig, 'numeric', ...
    'Position', [90, new_y+2, 50, 28], 'Value', 1, 'Limits', [0.5, 10]);
uilabel(fig, 'Text', '线宽', 'Position', [145, new_y+5, 35, 22]);

chk_grid = uicheckbox(fig, 'Text', '显示网格', ...
    'Position', [200, new_y+2, 80, 25], 'Value', true);

chk_sync_x = uicheckbox(fig, 'Text', '同步X变量', ...
    'Position', [290, new_y+2, 95, 25], 'Value', true);
chk_sync_y = uicheckbox(fig, 'Text', '同步Y变量', ...
    'Position', [395, new_y+2, 95, 25], 'Value', true);

btn_swap = uibutton(fig, 'push', 'Text', '交换X/Y', ...
    'Position', [500, new_y+2, 80, 28], ...
    'ButtonPushedFcn', @(btn,~) swap_xy_vars());

% ----- 新增：坐标轴范围控制 -----
chk_axis_range = uicheckbox(fig, 'Text', '轴范围', ...
    'Position', [590, new_y+2, 60, 25], 'Value', false, ...
    'Tooltip', '启用后手动指定X/Y轴显示范围');
edit_xrange = uieditfield(fig, 'text', ...
    'Position', [660, new_y+2, 95, 28], ...
    'Placeholder', 'X: min max', 'Tooltip', '格式：min max  例如 0 10');
edit_yrange = uieditfield(fig, 'text', ...
    'Position', [765, new_y+2, 95, 28], ...
    'Placeholder', 'Y: min max', 'Tooltip', '格式：min max  例如 1e-5 1');

% 当轴范围复选框状态改变时，控制编辑框的启用状态
chk_axis_range.ValueChangedFcn = @(cb,~) set_range_edit_enable();
set_range_edit_enable();  % 初始同步

    function set_range_edit_enable()
        if chk_axis_range.Value
            edit_xrange.Enable = 'on';
            edit_yrange.Enable = 'on';
        else
            edit_xrange.Enable = 'off';
            edit_yrange.Enable = 'off';
        end
    end

% =============== 配置文件管理 ===============
config_y = new_y - 35;
uilabel(fig, 'Text', '配置文件:', 'Position', [30, config_y+5, 60, 22]);
config_dropdown = uidropdown(fig, 'Items', {}, ...
    'Position', [100, config_y+2, 150, 28], ...
    'ValueChangedFcn', @(dd,~) load_selected_config());
btn_save_config = uibutton(fig, 'push', 'Text', '保存配置', ...
    'Position', [260, config_y, 80, 30], ...
    'ButtonPushedFcn', @(btn,~) save_config());
btn_delete_config = uibutton(fig, 'push', 'Text', '删除配置', ...
    'Position', [350, config_y, 80, 30], ...
    'ButtonPushedFcn', @(btn,~) delete_selected_config());
current_config_label = uilabel(fig, 'Text', '当前: 无', ...
    'Position', [440, config_y+5, 300, 22], 'FontAngle', 'italic');

status = uilabel(fig, 'Text', '状态: 请选择MAT文件', ...
    'Position', [30, config_y-35, 600, 30], 'FontColor', [0.1,0.5,0.1], 'FontSize', 11);

% ==================== 滚动面板 ====================
scroll_panel = uipanel(fig, 'Position', [30, 80, 950, 310], ...
    'Scrollable', 'on', 'Title', '文件变量与绘图选项', 'FontSize', 12, ...
    'BackgroundColor', [0.95,0.95,0.95]);

% ==================== 绘图按钮 ====================
btn_plot = uibutton(fig, 'push', 'Text', '开始绘图', ...
    'Position', [410, 30, 200, 45], 'BackgroundColor', [0.3,0.7,0.3], ...
    'FontColor', 'w', 'FontSize', 13, 'FontWeight', 'bold', ...
    'Enable', 'off', 'ButtonPushedFcn', @(btn, ~) plot_data());

% ==================== 全局数据 ====================
original_files = {};
original_configs = {};
current_files = {};
current_configs = {};
current_orig_indices = [];
file_widgets = {};
default_mat_folder = '';

auto_colors_rgb = [
    0 0 1; 1 0 0; 0 1 0; 1 0 1; 0 1 1; 0 0 0; 1 1 0;
    1 0.5 0; 0.5 0 0.5; 0 0.5 0.5; 0.5 0.5 0; 0.5 0 0;
    0 0.5 0; 0 0 0.5; 1 0.5 0.5; 0.5 1 0.5; 0.5 0.5 1;
    0.75 0.75 0; 0.75 0 0.75; 0 0.75 0.75
    ];

sync_in_progress = false;

% ==================== 配置文件路径 ====================
config_dir = fullfile(script_dir, 'config');
if ~exist(config_dir, 'dir'); mkdir(config_dir); end
last_config_file = fullfile(config_dir, 'multiplot_last_used_config.txt');

% ==================== 辅助函数 ====================
    function display_name = get_short_name_for_display(fullpath)
        [~, n] = fileparts(fullpath);
        display_name = strrep(n, '_', '\_');
    end

    function update_file_list_display()
        if isempty(original_files)
            txt_files.Value = {''};
        else
            file_names = cellfun(@get_short_name_for_display, original_files, 'UniformOutput', false);
            txt_files.Value = strjoin(file_names, sprintf('\n'));
        end
    end

    function safe_name = get_safe_filename_from_title()
        title_str = strtrim(edit_title.Value);
        if isempty(title_str); title_str = '未命名配置'; end
        illegal = '[\\/*?:"<>|]';
        safe_title = regexprep(title_str, illegal, '_');
        safe_title = strrep(safe_title, ' ', '_');
        safe_title = strrep(safe_title, '.', '_');
        if length(safe_title) > 60; safe_title = safe_title(1:60); end
        safe_name = [CONFIG_PREFIX, safe_title, '.mat'];
    end

    function refresh_config_list()
        if ~exist(config_dir, 'dir'); mkdir(config_dir); end
        all_mat = dir(fullfile(config_dir, '*.mat'));
        files = all_mat(startsWith({all_mat.name}, CONFIG_PREFIX) & ~startsWith({all_mat.name}, 'last_used'));
        items = {};
        for k = 1:length(files)
            name = files(k).name;
            try
                data = load(fullfile(config_dir, name));
                if isfield(data, 'global_settings') && isfield(data.global_settings, 'title')
                    display_name = data.global_settings.title;
                else
                    display_name = name;
                end
            catch
                display_name = name;
            end
            items{end+1} = sprintf('%s (%s)', display_name, name);
        end
        config_dropdown.Items = items;
        if isempty(items); config_dropdown.Value = {}; else; config_dropdown.Value = items{1}; end
    end

    function filename = get_selected_config_filename()
        val = config_dropdown.Value;
        if isempty(val) || (ischar(val) && strcmp(val, '')); filename = ''; return; end
        tokens = regexp(val, '\((.+\.mat)\)$', 'tokens');
        if ~isempty(tokens); filename = tokens{1}{1}; else; filename = ''; end
    end

    function save_state_to_file(filename)
        global_settings = struct();
        global_settings.xlabel = edit_xlabel.Value;
        global_settings.ylabel = edit_ylabel.Value;
        global_settings.title = edit_title.Value;
        global_settings.chk_global_type = chk_global_type.Value;
        global_settings.global_type = global_type.Value;
        global_settings.chk_global_linestyle = chk_global_linestyle.Value;
        global_settings.global_linestyle = global_linestyle.Value;
        global_settings.chk_global_marker = chk_global_marker.Value;
        global_settings.global_marker = global_marker.Value;
        global_settings.chk_default_x = chk_default_x.Value;
        global_settings.axis_mode = axis_mode.Value;
        global_settings.chk_global_linewidth = chk_global_linewidth.Value;
        global_settings.edit_linewidth = edit_linewidth.Value;
        global_settings.chk_grid = chk_grid.Value;
        global_settings.keyword = edit_keyword.Value;
        global_settings.subplot_mode = subplot_mode.Value;
        
        % 新增：保存坐标轴范围控制
        global_settings.chk_axis_range = chk_axis_range.Value;
        global_settings.edit_xrange = edit_xrange.Value;
        global_settings.edit_yrange = edit_yrange.Value;
        
        if ~isempty(original_files)
            abs_default = fileparts(original_files{1});
            global_settings.default_folder = get_rel_path(abs_default, script_dir);
        else
            global_settings.default_folder = '';
        end

        rel_files = cellfun(@(f) get_rel_path(f, script_dir), original_files, 'UniformOutput', false);
        config_data = struct();
        config_data.original_files = rel_files;
        config_data.original_configs = original_configs;
        config_data.global_settings = global_settings;
        save(fullfile(config_dir, filename), '-struct', 'config_data');
    end

    function save_config()
        default_name = get_safe_filename_from_title();
        save_state_to_file(default_name);
        refresh_config_list();
        new_item = sprintf('%s (%s)', edit_title.Value, default_name);
        idx = find(strcmp(config_dropdown.Items, new_item));
        if ~isempty(idx); config_dropdown.Value = new_item; end
        current_config_label.Text = sprintf('当前: %s', edit_title.Value);
        status.Text = sprintf('配置已保存为: %s', default_name);
    end

    function load_selected_config()
        filename = get_selected_config_filename();
        if isempty(filename); return; end
        fullpath = fullfile(config_dir, filename);
        if ~exist(fullpath, 'file'); status.Text = '配置文件不存在'; refresh_config_list(); return; end
        try
            config_data = load(fullpath);
            if isfield(config_data, 'original_files')
                rel_list = config_data.original_files;
                abs_list = cell(size(rel_list));
                for i = 1:length(rel_list)
                    abs_list{i} = get_abs_path(rel_list{i}, script_dir);
                    if ~exist(abs_list{i}, 'file')
                        warning('配置文件中的文件不存在: %s', rel_list{i});
                    end
                end
                original_files = abs_list(:);
                if isfield(config_data, 'original_configs')
                    original_configs = config_data.original_configs;
                else
                    n_orig = length(original_files);
                    original_configs = cell(n_orig,1);
                    for i = 1:n_orig
                        original_configs{i} = struct();
                        original_configs{i}.fixed = false;
                        original_configs{i}.plotType = '曲线';
                        original_configs{i}.lineStyle = '-';
                        original_configs{i}.marker = 'none';
                        original_configs{i}.subplots = '1';
                    end
                end
                % 确保每个配置都有 subplots 字段
                for i = 1:length(original_configs)
                    if ~isfield(original_configs{i}, 'subplots')
                        original_configs{i}.subplots = '1';
                    end
                end
                if isfield(config_data, 'global_settings')
                    gs = config_data.global_settings;
                    if isfield(gs, 'xlabel'); edit_xlabel.Value = gs.xlabel; end
                    if isfield(gs, 'ylabel'); edit_ylabel.Value = gs.ylabel; end
                    if isfield(gs, 'title'); edit_title.Value = gs.title; end
                    if isfield(gs, 'chk_global_type'); chk_global_type.Value = gs.chk_global_type; end
                    if isfield(gs, 'global_type'); global_type.Value = gs.global_type; end
                    if isfield(gs, 'chk_global_linestyle'); chk_global_linestyle.Value = gs.chk_global_linestyle; end
                    if isfield(gs, 'global_linestyle'); global_linestyle.Value = gs.global_linestyle; end
                    if isfield(gs, 'chk_global_marker'); chk_global_marker.Value = gs.chk_global_marker; end
                    if isfield(gs, 'global_marker'); global_marker.Value = gs.global_marker; end
                    if isfield(gs, 'chk_default_x'); chk_default_x.Value = gs.chk_default_x; end
                    if isfield(gs, 'axis_mode'); axis_mode.Value = gs.axis_mode; end
                    if isfield(gs, 'chk_global_linewidth'); chk_global_linewidth.Value = gs.chk_global_linewidth; end
                    if isfield(gs, 'edit_linewidth'); edit_linewidth.Value = gs.edit_linewidth; end
                    if isfield(gs, 'chk_grid'); chk_grid.Value = gs.chk_grid; end
                    if isfield(gs, 'keyword'); edit_keyword.Value = gs.keyword; end
                    if isfield(gs, 'subplot_mode'); subplot_mode.Value = gs.subplot_mode;
                    elseif isfield(gs, 'subplot_rows') && isfield(gs, 'subplot_cols')
                        r = gs.subplot_rows; c = gs.subplot_cols;
                        if r==1 && c==1; subplot_mode.Value = '1x1';
                        elseif r==1 && c==2; subplot_mode.Value = '1x2';
                        else; subplot_mode.Value = '2x2';
                        end
                    else
                        subplot_mode.Value = '1x1';
                    end
                    
                    % 新增：加载坐标轴范围控制
                    if isfield(gs, 'chk_axis_range'); chk_axis_range.Value = gs.chk_axis_range; end
                    if isfield(gs, 'edit_xrange'); edit_xrange.Value = gs.edit_xrange; end
                    if isfield(gs, 'edit_yrange'); edit_yrange.Value = gs.edit_yrange; end
                    set_range_edit_enable(); % 根据复选框更新编辑框启用状态
                    
                    if ~isempty(original_files) && exist(original_files{1}, 'file')
                        default_mat_folder = fileparts(original_files{1});
                    elseif isfield(gs, 'default_folder') && ~isempty(gs.default_folder)
                        abs_default = get_abs_path(gs.default_folder, script_dir);
                        if exist(abs_default, 'dir'); default_mat_folder = abs_default; else; default_mat_folder = ''; end
                    else
                        default_mat_folder = '';
                    end
                end
                refresh_display(original_files, original_configs, (1:length(original_files))');
                current_config_label.Text = sprintf('当前: %s', edit_title.Value);
                status.Text = sprintf('已加载配置: %s', filename);
                save_last_used(filename);
            else
                status.Text = '配置文件格式无效';
            end
        catch ME
            status.Text = sprintf('加载失败: %s', ME.message);
        end
    end

    function delete_selected_config()
        filename = get_selected_config_filename();
        if isempty(filename); status.Text = '没有选中任何配置文件'; return; end
        choice = uiconfirm(fig, sprintf('确定删除配置文件 "%s" 吗？', filename), ...
            '删除确认', 'Options', {'删除','取消'}, 'DefaultOption', 2);
        if strcmp(choice, '取消'); return; end
        fullpath = fullfile(config_dir, filename);
        if exist(fullpath, 'file')
            delete(fullpath);
            status.Text = sprintf('已删除配置: %s', filename);
            refresh_config_list();
            if strcmp(current_config_label.Text, sprintf('当前: %s', edit_title.Value)) && exist(fullpath,'file')==0
                if ~isempty(config_dropdown.Items); load_selected_config(); else
                    original_files = {}; original_configs = {};
                    refresh_display({},{},[]);
                    current_config_label.Text = '当前: 无';
                end
            end
        else
            status.Text = '文件不存在，刷新列表';
            refresh_config_list();
        end
    end

    function save_last_used(filename)
        fid = fopen(last_config_file, 'w');
        if fid ~= -1; fprintf(fid, '%s', filename); fclose(fid); end
    end

    function auto_load_last_config()
        if exist(last_config_file, 'file')
            fid = fopen(last_config_file, 'r');
            if fid ~= -1
                last_name = fgetl(fid); fclose(fid);
                if ~isempty(last_name) && startsWith(last_name, CONFIG_PREFIX) && ...
                        exist(fullfile(config_dir, last_name), 'file')
                    refresh_config_list();
                    items = config_dropdown.Items;
                    target_item = '';
                    for k = 1:length(items)
                        if contains(items{k}, last_name); target_item = items{k}; break; end
                    end
                    if ~isempty(target_item)
                        config_dropdown.Value = target_item;
                        load_selected_config();
                        return;
                    end
                end
            end
        end
        refresh_config_list();
        if ~isempty(config_dropdown.Items); load_selected_config(); else
            status.Text = '无保存的配置，请选择MAT文件并保存配置';
        end
    end

% ==================== 删除指定文件 ====================
    function delete_file(orig_idx)
        if isempty(original_files) || orig_idx > length(original_files); return; end
        [~, fname] = fileparts(original_files{orig_idx}); 
        original_files(orig_idx) = [];
        original_configs(orig_idx) = [];
        if isempty(original_files); default_mat_folder = '';
        elseif orig_idx == 1 && ~isempty(original_files); default_mat_folder = fileparts(original_files{1}); end
        edit_keyword.Value = '';
        reset_filter();
        status.Text = sprintf('已删除文件 "%s"，当前共 %d 个文件', fname, length(original_files));
    end

% ==================== 同步函数 ====================
    function on_x_selected(idx, dx_widget)
        new_val = dx_widget.Value;
        update_config_var(idx, 'xvar', new_val);
        if ~chk_sync_x.Value || sync_in_progress; return; end
        sync_in_progress = true;
        for k = 1:length(file_widgets)
            if k == idx; continue; end
            w = file_widgets{k};
            if any(strcmp(w.dx.Items, new_val))
                w.dx.Value = new_val;
            else
                status.Text = sprintf('警告: 文件 %d 中不存在变量 %s，同步X跳过', k, new_val);
            end
        end
        sync_in_progress = false;
    end

    function on_y_selected(idx, dy_widget)
        new_val = dy_widget.Value;
        update_config_var(idx, 'yvar', new_val);
        if ~chk_sync_y.Value || sync_in_progress; return; end
        sync_in_progress = true;
        for k = 1:length(file_widgets)
            if k == idx; continue; end
            w = file_widgets{k};
            if any(strcmp(w.dy.Items, new_val))
                w.dy.Value = new_val;
            else
                status.Text = sprintf('警告: 文件 %d 中不存在变量 %s，同步Y跳过', k, new_val);
            end
        end
        sync_in_progress = false;
    end

    function apply_sync_to_all()
        if isempty(file_widgets); return; end
        if chk_sync_x.Value
            base_x = file_widgets{1}.dx.Value;
            sync_in_progress = true;
            for k = 2:length(file_widgets)
                w = file_widgets{k};
                if any(strcmp(w.dx.Items, base_x)); w.dx.Value = base_x; end
            end
            sync_in_progress = false;
        end
        if chk_sync_y.Value
            base_y = file_widgets{1}.dy.Value;
            sync_in_progress = true;
            for k = 2:length(file_widgets)
                w = file_widgets{k};
                if any(strcmp(w.dy.Items, base_y)); w.dy.Value = base_y; end
            end
            sync_in_progress = false;
        end
    end

    function swap_xy_vars()
        if isempty(file_widgets); status.Text = '没有文件可交换变量'; return; end
        sync_in_progress = true;
        for i = 1:length(file_widgets)
            w = file_widgets{i};
            x_val = w.dx.Value; y_val = w.dy.Value;
            if ~any(strcmp(w.dy.Items, x_val)) || ~any(strcmp(w.dx.Items, y_val))
                status.Text = sprintf('文件 %d: 交换失败，变量不存在于对方下拉列表', i);
                sync_in_progress = false; return;
            end
            w.dx.Value = y_val; w.dy.Value = x_val;
            update_config_var(i, 'xvar', y_val);
            update_config_var(i, 'yvar', x_val);
        end
        sync_in_progress = false;
        if chk_sync_x.Value || chk_sync_y.Value; apply_sync_to_all(); end
        status.Text = '已成功交换所有文件的X和Y变量';
    end

% ==================== 界面刷新（含子图编辑框） ====================
    function refresh_display(files, configs, orig_indices)
        current_files = files;
        current_configs = configs;
        current_orig_indices = orig_indices;
        n = length(current_files);
        delete(allchild(scroll_panel));
        file_widgets = cell(n, 1);
        if n == 0
            btn_plot.Enable = 'off';
            status.Text = '当前无文件（可重置筛选或重新选择）';
            update_file_list_display();
            return;
        end
        row_height = 70;
        panel_content_height = n * row_height + 20;
        start_y = panel_content_height - 30;
        for i = 1:n
            full_fname = current_files{i};
            [~, fname] = fileparts(full_fname);
            if length(fname) > 22; fname = [fname(1:19), '...']; end
            vars = fieldnames(load(current_files{i}));
            if isempty(vars); vars = {'(无变量)'}; end
            y_pos = start_y - (i-1) * row_height;

            uilabel(scroll_panel, 'Text', fname, ...
                'Position', [10, y_pos, 130, 28], ...
                'FontWeight', 'bold', 'Tooltip', current_files{i});

            dx = uidropdown(scroll_panel, 'Items', vars, ...
                'Position', [150, y_pos, 120, 28]);
            dy = uidropdown(scroll_panel, 'Items', vars, ...
                'Position', [280, y_pos, 120, 28]);
            dplot = uidropdown(scroll_panel, 'Items', {'曲线', '竖线'}, ...
                'Position', [410, y_pos, 70, 28]);
            dls = uidropdown(scroll_panel, 'Items', {'-', '--', ':', '-.'}, ...
                'Position', [485, y_pos, 70, 28]);
            dmark = uidropdown(scroll_panel, 'Items', ...
                {'none','o','+','*','.','x','s','d','^','v','>','<','p','h'}, ...
                'Position', [560, y_pos, 70, 28]);
            
            % 子图编辑框
            sub_edit = uieditfield(scroll_panel, 'text', ...
                'Position', [640, y_pos, 50, 28], 'Tooltip', '子图编号，支持多个(如1,2)');
            
            % 手动、颜色、固定、删除向右平移
            chk_manual = uicheckbox(scroll_panel, 'Text', '手动', ...
                'Position', [700, y_pos+2, 55, 28]);
            btn_color = uibutton(scroll_panel, 'push', 'Text', '选颜色', ...
                'Position', [760, y_pos, 65, 28], ...
                'BackgroundColor', [0.8,0.8,0.8], 'Enable', 'off');
            chk_fixed = uicheckbox(scroll_panel, 'Text', '固定', ...
                'Position', [835, y_pos+2, 55, 28]);
            btn_del = uibutton(scroll_panel, 'push', 'Text', '删除', ...
                'Position', [895, y_pos+2, 55, 28], ...
                'BackgroundColor', [0.8,0.8,0.8], ...
                'ButtonPushedFcn', @(~,~) delete_file(current_orig_indices(i)));

            cfg = current_configs{i};
            if ~isempty(cfg)
                if isfield(cfg, 'xvar') && any(strcmp(cfg.xvar, vars)); dx.Value = cfg.xvar;
                else; dx.Value = vars{1}; end
                if isfield(cfg, 'yvar') && any(strcmp(cfg.yvar, vars)); dy.Value = cfg.yvar;
                else; if length(vars)>=2; dy.Value=vars{2}; else; dy.Value=vars{1}; end; end
                if isfield(cfg, 'plotType'); dplot.Value = cfg.plotType; else; dplot.Value='曲线'; end
                if isfield(cfg, 'lineStyle'); dls.Value = cfg.lineStyle; else; dls.Value='-'; end
                if isfield(cfg, 'marker'); dmark.Value = cfg.marker; else; dmark.Value='none'; end
                if isfield(cfg, 'subplots'); sub_edit.Value = cfg.subplots; else; sub_edit.Value = '1'; end
                manual_flag = isfield(cfg,'manual') && cfg.manual;
                manual_color = [];
                if manual_flag && isfield(cfg,'manualColor'); manual_color = cfg.manualColor; end
                fixed_flag = isfield(cfg,'fixed') && cfg.fixed;
            else
                dx.Value = vars{1};
                if length(vars)>=2; dy.Value=vars{2}; else; dy.Value=vars{1}; end
                dplot.Value='曲线'; dls.Value='-'; dmark.Value='none';
                sub_edit.Value = '1';
                manual_flag=false; manual_color=[]; fixed_flag=false;
            end

            uilabel(scroll_panel, 'Text', 'X', 'Position', [210, y_pos+30, 20, 18]);
            uilabel(scroll_panel, 'Text', 'Y', 'Position', [340, y_pos+30, 20, 18]);
            uilabel(scroll_panel, 'Text', '类型', 'Position', [415, y_pos+30, 30, 18]);
            uilabel(scroll_panel, 'Text', '线型', 'Position', [490, y_pos+30, 30, 18]);
            uilabel(scroll_panel, 'Text', '标记', 'Position', [565, y_pos+30, 30, 18]);
            uilabel(scroll_panel, 'Text', '子图', 'Position', [645, y_pos+30, 30, 18]);

            if manual_flag && ~isempty(manual_color); btn_color.BackgroundColor = manual_color; end
            chk_manual.Value = manual_flag;
            chk_fixed.Value = fixed_flag;
            if ~manual_flag; btn_color.Enable = 'off'; end

            file_widgets{i} = struct('dx', dx, 'dy', dy, ...
                'dplot', dplot, 'dls', dls, 'dmark', dmark, ...
                'sub_edit', sub_edit, ...
                'chk_manual', chk_manual, 'btn_color', btn_color, 'manualColor', manual_color, ...
                'chk_fixed', chk_fixed, 'fixed', fixed_flag);

            dx.ValueChangedFcn = @(~,~) on_x_selected(i, dx);
            dy.ValueChangedFcn = @(~,~) on_y_selected(i, dy);
            dplot.ValueChangedFcn = @(~,~) update_config_var(i, 'plotType', dplot.Value);
            dls.ValueChangedFcn   = @(~,~) update_config_var(i, 'lineStyle', dls.Value);
            dmark.ValueChangedFcn = @(~,~) update_config_var(i, 'marker', dmark.Value);
            sub_edit.ValueChangedFcn = @(~,~) update_config_var(i, 'subplots', sub_edit.Value);
            chk_manual.ValueChangedFcn = @(~,~) toggle_manual(i);
            btn_color.ButtonPushedFcn = @(~,~) choose_color(i);
            chk_fixed.ValueChangedFcn = @(~,~) toggle_fixed(i);
        end
        btn_plot.Enable = 'on';
        status.Text = sprintf('当前显示 %d 个文件（共 %d 个）', n, length(original_files));
        apply_sync_to_all();
        update_file_list_display();
    end

    function sync_config_to_original(display_idx, field, value)
        if display_idx > length(current_configs) || isempty(current_configs{display_idx})
            current_configs{display_idx} = struct();
        end
        current_configs{display_idx}.(field) = value;
        orig_idx = current_orig_indices(display_idx);
        if orig_idx > length(original_configs) || isempty(original_configs{orig_idx})
            original_configs{orig_idx} = struct();
        end
        original_configs{orig_idx}.(field) = value;
    end

    function update_config_var(idx, field, value)
        sync_config_to_original(idx, field, value);
    end

    function toggle_manual(idx)
        w = file_widgets{idx};
        if w.chk_manual.Value
            w.btn_color.Enable = 'on';
            if isempty(w.manualColor); w.manualColor = w.btn_color.BackgroundColor; end
            file_widgets{idx} = w;
            sync_config_to_original(idx, 'manual', true);
            sync_config_to_original(idx, 'manualColor', w.manualColor);
        else
            w.btn_color.Enable = 'off';
            w.manualColor = [];
            file_widgets{idx} = w;
            sync_config_to_original(idx, 'manual', false);
            if isfield(current_configs{idx}, 'manualColor')
                current_configs{idx} = rmfield(current_configs{idx}, 'manualColor');
            end
            orig_idx = current_orig_indices(idx);
            if isfield(original_configs{orig_idx}, 'manualColor')
                original_configs{orig_idx} = rmfield(original_configs{orig_idx}, 'manualColor');
            end
        end
    end

    function choose_color(idx)
        w = file_widgets{idx};
        newc = uisetcolor(w.btn_color.BackgroundColor, '选择线条颜色');
        if ~isequal(newc, 0)
            w.manualColor = newc;
            w.btn_color.BackgroundColor = newc;
            file_widgets{idx} = w;
            sync_config_to_original(idx, 'manual', true);
            sync_config_to_original(idx, 'manualColor', newc);
        end
    end

    function toggle_fixed(idx)
        w = file_widgets{idx};
        w.fixed = w.chk_fixed.Value;
        file_widgets{idx} = w;
        sync_config_to_original(idx, 'fixed', w.fixed);
        if w.fixed; status.Text = sprintf('文件已固定，筛选时始终显示');
        else; status.Text = sprintf('文件已取消固定，筛选时可能被过滤'); end
    end

% ==================== 添加文件 ====================
    function add_files()
        start_path = '';
        if ~isempty(original_files) && exist(original_files{1}, 'file')
            start_path = fileparts(original_files{1});
        elseif ~isempty(default_mat_folder) && exist(default_mat_folder, 'dir')
            start_path = default_mat_folder;
        end
        if isempty(start_path)
            [names, path] = uigetfile('*.mat', '选择要添加的 MAT 文件', 'MultiSelect', 'on');
        else
            [names, path] = uigetfile('*.mat', '选择要添加的 MAT 文件', start_path, 'MultiSelect', 'on');
        end
        if isequal(names, 0); status.Text = '未选择文件'; return; end
        if ischar(names); names = {names}; end
        new_files_abs = cellfun(@(f) fullfile(path, f), names, 'UniformOutput', false);
        new_files_abs = new_files_abs(:);
        if isempty(original_files)
            unique_new = new_files_abs; dup_count = 0;
        else
            existing = false(size(new_files_abs));
            for i = 1:length(new_files_abs)
                if any(strcmp(new_files_abs{i}, original_files)); existing(i) = true; end
            end
            unique_new = new_files_abs(~existing);
            dup_count = sum(existing);
        end
        if isempty(unique_new)
            status.Text = sprintf('所有选择的文件都已存在，未添加任何新文件（跳过 %d 个重复项）', length(new_files_abs));
            return;
        end
        original_files = [original_files(:); unique_new];
        n_new = length(unique_new);
        new_configs = cell(n_new, 1);
        for i = 1:n_new
            new_configs{i} = struct();
            new_configs{i}.fixed = false;
            new_configs{i}.plotType = '曲线';
            new_configs{i}.lineStyle = '-';
            new_configs{i}.marker = 'none';
            new_configs{i}.subplots = '1';
        end
        original_configs = [original_configs(:); new_configs(:)];
        if isempty(default_mat_folder) && ~isempty(original_files)
            default_mat_folder = fileparts(original_files{1});
        end
        edit_keyword.Value = '';
        refresh_display(original_files, original_configs, (1:length(original_files))');
        if dup_count > 0
            status.Text = sprintf('已添加 %d 个新文件，跳过 %d 个重复文件，当前共 %d 个文件', n_new, dup_count, length(original_files));
        else
            status.Text = sprintf('已添加 %d 个文件，当前共 %d 个文件', n_new, length(original_files));
        end
    end

    function clear_all_files()
        if isempty(original_files); status.Text = '当前文件列表已为空'; return; end
        original_files = {}; original_configs = {};
        refresh_display({}, {}, []);
        btn_plot.Enable = 'off';
        status.Text = '已清空所有文件';
    end

% ==================== 筛选 ====================
    function apply_filter()
        if isempty(original_files); status.Text = '没有文件可筛选，请先选择MAT文件'; return; end
        keyword_str = strtrim(edit_keyword.Value);
        if isempty(keyword_str)
            refresh_display(original_files, original_configs, (1:length(original_files))');
            return;
        end
        keywords = strsplit(keyword_str, ' ');
        keywords(cellfun(@isempty, keywords)) = [];
        show_idx = false(length(original_files), 1);
        for i = 1:length(original_files)
            if isfield(original_configs{i}, 'fixed') && original_configs{i}.fixed
                show_idx(i) = true; continue;
            end
            [~, fname] = fileparts(original_files{i});
            all_match = true;
            for k = 1:length(keywords)
                if ~contains(fname, keywords{k}, 'IgnoreCase', true); all_match=false; break; end
            end
            if all_match; show_idx(i)=true; end
        end
        if ~any(show_idx); status.Text = '没有文件名匹配关键词'; refresh_display({},{},[]); return; end
        new_files = original_files(show_idx);
        new_configs = original_configs(show_idx);
        new_orig_indices = find(show_idx);
        refresh_display(new_files, new_configs, new_orig_indices);
    end

    function reset_filter()
        if isempty(original_files); status.Text = '没有原始文件列表'; return; end
        refresh_display(original_files, original_configs, (1:length(original_files))');
        edit_keyword.Value = '';
    end

% ==================== 绘图函数（支持三种子图模式） ====================
    function plot_data()
        n = length(current_files);
        if n == 0; status.Text = '没有文件，请先选择或重置筛选'; return; end
        for i = 1:n
            w = file_widgets{i};
            if isempty(w.dy.Value); status.Text = sprintf('文件 %d 未选Y变量', i); return; end
        end

        % 根据子图模式确定行列数
        mode = subplot_mode.Value;
        switch mode
            case '1x1'
                sub_rows = 1; sub_cols = 1;
            case '1x2'
                sub_rows = 1; sub_cols = 2;
            case '2x2'
                sub_rows = 2; sub_cols = 2;
            otherwise
                sub_rows = 1; sub_cols = 1;
        end
        total_subplots = sub_rows * sub_cols;

        use_global_type = chk_global_type.Value;
        global_type_val = global_type.Value;
        use_global_linestyle = chk_global_linestyle.Value;
        global_linestyle_val = global_linestyle.Value;
        use_global_marker = chk_global_marker.Value;
        global_marker_val = global_marker.Value;
        use_default_x = chk_default_x.Value;
        axis_mode_val = axis_mode.Value;
        use_global_linewidth = chk_global_linewidth.Value;
        global_linewidth = edit_linewidth.Value;
        show_grid = chk_grid.Value;
        
        % 获取轴范围设置
        use_axis_range = chk_axis_range.Value;
        xrange_str = strtrim(edit_xrange.Value);
        yrange_str = strtrim(edit_yrange.Value);
        xlim_custom = []; ylim_custom = [];
        if use_axis_range && ~isempty(xrange_str)
            parts = strsplit(xrange_str, ' ');
            if length(parts) == 2
                xmin = str2double(strtrim(parts{1}));
                xmax = str2double(strtrim(parts{2}));
                if ~isnan(xmin) && ~isnan(xmax) && xmin < xmax
                    xlim_custom = [xmin, xmax];
                else
                    warning('无效的X轴范围: %s', xrange_str);
                end
            else
                warning('X轴范围格式应为 "min,max"');
            end
        end
        if use_axis_range && ~isempty(yrange_str)
            parts = strsplit(yrange_str, ',');
            if length(parts) == 2
                ymin = str2double(strtrim(parts{1}));
                ymax = str2double(strtrim(parts{2}));
                if ~isnan(ymin) && ~isnan(ymax) && ymin < ymax
                    ylim_custom = [ymin, ymax];
                else
                    warning('无效的Y轴范围: %s', yrange_str);
                end
            else
                warning('Y轴范围格式应为 "min,max"');
            end
        end

        % 收集手动颜色
        manual_indices = []; manual_colors = [];
        for i = 1:n
            w = file_widgets{i};
            if w.chk_manual.Value && ~isempty(w.manualColor)
                manual_indices = [manual_indices, i];
                manual_colors = [manual_colors; w.manualColor];
            end
        end
        avail_colors = auto_colors_rgb;
        for k = 1:size(manual_colors,1)
            mc = manual_colors(k,:);
            matches = all(abs(avail_colors - mc) < 1e-6, 2);
            idx = find(matches,1);
            if ~isempty(idx); avail_colors(idx,:) = []; end
        end
        if isempty(avail_colors); avail_colors = [0.5,0.5,0.5]; end
        auto_indices = setdiff(1:n, manual_indices);
        colors = cell(n,1);
        for k = 1:length(auto_indices)
            i = auto_indices(k);
            color_idx = mod(k-1, size(avail_colors,1)) + 1;
            colors{i} = avail_colors(color_idx, :);
        end
        for k = 1:length(manual_indices)
            i = manual_indices(k);
            colors{i} = manual_colors(k, :);
        end

        figure('Name', sprintf('绘图结果 (%s 子图)', mode), 'Position', [200,150,1000,600]);

        % 解析每个文件需要绘制的子图编号
        file_subplots = cell(n,1);
        for i = 1:n
            w = file_widgets{i};
            sub_str = strtrim(w.sub_edit.Value);
            if isempty(sub_str)
                file_subplots{i} = [];
                continue;
            end
            tokens = regexp(sub_str, '[0-9]+', 'match');
            sub_nums = [];
            for t = 1:length(tokens)
                num = str2double(tokens{t});
                if ~isnan(num) && num >= 1 && num <= total_subplots
                    sub_nums(end+1) = num;
                else
                    warning('无效子图编号: %s (超出范围1-%d)', tokens{t}, total_subplots);
                end
            end
            file_subplots{i} = unique(sub_nums);
        end

        for sub_idx = 1:total_subplots
            subplot(sub_rows, sub_cols, sub_idx);
            hold on;
            if show_grid; grid on; else; grid off; end
            for i = 1:n
                if isempty(file_subplots{i}) || ~ismember(sub_idx, file_subplots{i})
                    continue;
                end
                w = file_widgets{i};
                data = load(current_files{i});
                Y = data.(w.dy.Value)(:);
                if use_default_x
                    X = (1:length(Y))';
                else
                    if isempty(w.dx.Value); continue; end
                    X = data.(w.dx.Value)(:);
                    if length(X) ~= length(Y)
                        min_len = min(length(X), length(Y));
                        X = X(1:min_len); Y = Y(1:min_len);
                    end
                end
                if use_global_type; plotType = global_type_val; else; plotType = w.dplot.Value; end
                if use_global_linestyle; lineStyle = global_linestyle_val; else; lineStyle = w.dls.Value; end
                if use_global_marker; marker = global_marker_val; else; marker = w.dmark.Value; end
                if use_global_linewidth; linewidth = global_linewidth; else; linewidth = 0.5; end
                color = colors{i};
                switch plotType
                    case '曲线'
                        plot(X, Y, 'Color', color, 'LineWidth', linewidth, ...
                            'LineStyle', lineStyle, 'Marker', marker, ...
                            'DisplayName', get_short_name_for_display(current_files{i}));
                    case '竖线'
                        if strcmp(marker, 'none')
                            h = stem(X, Y, 'Color', color, 'LineWidth', linewidth, ...
                                'LineStyle', lineStyle, 'ShowBaseLine', 'off', ...
                                'Marker', 'none');
                        else
                            h = stem(X, Y, 'Color', color, 'LineWidth', linewidth, ...
                                'LineStyle', lineStyle, 'ShowBaseLine', 'off', ...
                                'Marker', marker, 'MarkerSize', 6, 'MarkerFaceColor', color);
                        end
                        set(get(h, 'Children'), 'DisplayName', get_short_name_for_display(current_files{i}));
                end
            end
            if sub_idx == 1
                if use_default_x
                    xlabel('默认索引 (采样点)', 'FontSize', 10);
                else
                    xlabel(edit_xlabel.Value, 'FontSize', 10);
                end
                ylabel(edit_ylabel.Value, 'FontSize', 10);
                title(edit_title.Value, 'FontSize', 12, 'FontWeight', 'bold');
            else
                if use_default_x
                    xlabel('默认索引');
                else
                    xlabel(edit_xlabel.Value);
                end
                ylabel(edit_ylabel.Value);
                title(edit_title.Value, 'FontSize', 12, 'FontWeight', 'bold');
            end
            
            % 坐标轴对数设置
            switch axis_mode_val
                case 'X轴对数'; set(gca, 'XScale', 'log');
                case 'Y轴对数'; set(gca, 'YScale', 'log');
                case '双对数'; set(gca, 'XScale', 'log', 'YScale', 'log');
            end
            
            % 应用自定义轴范围（必须在坐标轴类型设置之后）
            if use_axis_range
                if ~isempty(xlim_custom); xlim(xlim_custom); end
                if ~isempty(ylim_custom); ylim(ylim_custom); end
            end
            
            legend('Location', 'best');
        end

        status.Text = sprintf('绘图完成！子图布局: %s', mode);
    end

% ==================== 相对路径辅助 ====================
    function rel = get_rel_path(abs_path, base_dir)
        if isempty(abs_path); rel=''; return; end
        abs_path = strrep(abs_path, '/', filesep);
        base_dir = strrep(base_dir, '/', filesep);
        if startsWith(abs_path, base_dir, 'IgnoreCase', true)
            rel = abs_path(length(base_dir)+2:end);
        else
            rel = abs_path;
        end
    end

    function abs_path = get_abs_path(path_candidate, base_dir)
        if isempty(path_candidate); abs_path=''; return; end
        if exist(path_candidate, 'file')==2; abs_path=path_candidate; return; end
        candidate = fullfile(base_dir, path_candidate);
        if exist(candidate, 'file')==2; abs_path=candidate; else; abs_path=path_candidate; end
    end

% ==================== 程序入口 ====================
auto_load_last_config();
chk_sync_x.ValueChangedFcn = @(~,~) apply_sync_to_all();
chk_sync_y.ValueChangedFcn = @(~,~) apply_sync_to_all();

end