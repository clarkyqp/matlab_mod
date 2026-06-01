clear; close all;
matVarDeleterUI();
function matVarDeleterUI()
% matVarDeleterUI 图形界面：从多个 MAT 文件中批量删除指定变量
%   支持同时处理多个 .mat 文件，可预览每个文件的变量，多选要删除的变量，
%   确认后从所有选中的文件中删除这些变量（直接覆盖原文件）。

% 创建主窗口
fig = uifigure('Name', 'MAT 文件变量批量删除工具', 'Position', [300 200 750 500], ...
    'Resize', 'on');

% 左侧面板：文件操作区域
leftPanel = uipanel(fig, 'Title', '文件列表', 'Position', [10 10 280 480], ...
    'BackgroundColor', [0.95 0.95 0.95]);

% 按钮：选择文件
btnSelect = uibutton(leftPanel, 'push', 'Text', '选择 MAT 文件', ...
    'Position', [20 440 120 30], 'ButtonPushedFcn', @(btn,event) selectFiles());

% 按钮：清空文件列表
btnClear = uibutton(leftPanel, 'push', 'Text', '清空列表', ...
    'Position', [150 440 100 30], 'ButtonPushedFcn', @(btn,event) clearFiles());

% 文件列表（显示文件名，存储完整路径）
fileListBox = uilistbox(leftPanel, 'Position', [20 130 240 300], ...
    'ValueChangedFcn', @(box,event) onFileSelected());

% 提示标签
lblFileHint = uilabel(leftPanel, 'Text', '选中文件以查看其变量', ...
    'Position', [20 100 240 20], 'FontSize', 10, 'FontColor', [0.4 0.4 0.4]);

% 右侧面板：变量操作区域
rightPanel = uipanel(fig, 'Title', '变量列表（可多选）', 'Position', [300 10 440 480], ...
    'BackgroundColor', [0.95 0.95 0.95]);

% 变量列表框（支持多选）
varListBox = uilistbox(rightPanel, 'Position', [20 130 400 300], ...
    'Multiselect', 'on', 'Value', {});

% 按钮：删除选中变量
btnDelete = uibutton(rightPanel, 'push', 'Text', '从所有文件中删除所选变量', ...
    'Position', [20 80 400 35], 'ButtonPushedFcn', @(btn,event) deleteVarsFromAll());

% 状态文本框（用于显示操作日志）
statusArea = uitextarea(rightPanel, 'Position', [20 20 400 50], ...
    'Editable', 'off', 'Value', '就绪。', 'WordWrap', 'on');

% 全局数据存储（使用 nested function 共享）
    % 存储文件完整路径及对应的变量名缓存
    files = {};          % cell array of full paths
    fileNames = {};      % display names (base name)
    varsCache = {};      % cell array, each element is cell array of variable names
    
    % -----------------------------------------------------------------
    % 选择文件回调
    function selectFiles()
        % 允许多选 .mat 文件
        [fileNamesSel, pathName] = uigetfile('*.mat', '选择一个或多个 MAT 文件', ...
            'MultiSelect', 'on');
        if isequal(fileNamesSel, 0)
            return;
        end
        
        % 转换为 cell 数组统一处理
        if ischar(fileNamesSel)
            fileNamesSel = {fileNamesSel};
        end
        
        newPaths = cellfun(@(f) fullfile(pathName, f), fileNamesSel, 'UniformOutput', false);
        
        % 去重：避免重复添加已存在的文件
        [~, idx] = setdiff(newPaths, files);
        newPaths = newPaths(idx);
        
        if isempty(newPaths)
            setStatus('所选文件均已存在于列表中。');
            return;
        end
        
        % 添加到全局列表
        files = [files; newPaths];
        fileNames = cellfun(@(f) getDisplayName(f), files, 'UniformOutput', false);
        
        % 为新文件预先加载变量名（异步处理，避免界面卡顿）
        newVars = cell(size(newPaths));
        for i = 1:numel(newPaths)
            try
                info = whos('-file', newPaths{i});
                newVars{i} = {info.name};
            catch ME
                newVars{i} = {};
                setStatus(sprintf('无法读取文件 %s：%s', newPaths{i}, ME.message));
            end
        end
        if isempty(varsCache)
            varsCache = newVars;
        else
            varsCache = [varsCache; newVars];
        end
        
        % 更新文件列表显示
        fileListBox.Items = fileNames;
        fileListBox.Value = {};   % 清空选中
        
        % 清空右侧变量列表
        varListBox.Items = {};
        varListBox.Value = {};
        setStatus(sprintf('已添加 %d 个文件，共 %d 个文件待处理。', numel(newPaths), numel(files)));
    end

    % -----------------------------------------------------------------
    % 清空文件列表
    function clearFiles()
        files = {};
        fileNames = {};
        varsCache = {};
        fileListBox.Items = {};
        fileListBox.Value = {};
        varListBox.Items = {};
        varListBox.Value = {};
        setStatus('文件列表已清空。');
    end

    % -----------------------------------------------------------------
    % 当用户选中某个文件时，显示该文件的变量列表
    function onFileSelected()
        idx = getSelectedFileIndex();
        if isempty(idx)
            varListBox.Items = {};
            varListBox.Value = {};
            return;
        end
        % 从缓存中获取变量名
        vars = varsCache{idx};
        if isempty(vars)
            % 尝试重新加载（可能之前加载失败）
            try
                info = whos('-file', files{idx});
                vars = {info.name};
                varsCache{idx} = vars;
            catch ME
                setStatus(sprintf('读取文件变量失败：%s', ME.message));
                vars = {};
            end
        end
        varListBox.Items = vars;
        varListBox.Value = {};   % 清空选中
        setStatus(sprintf('当前文件：%s，共 %d 个变量。', fileNames{idx}, numel(vars)));
    end

    % -----------------------------------------------------------------
    % 删除操作：将当前选中的变量从所有文件中删除
    function deleteVarsFromAll()
        if isempty(files)
            setStatus('没有选中任何文件，请先选择 MAT 文件。');
            return;
        end
        
        % 获取要删除的变量名（用户在多选列表中选择的）
        varsToDel = varListBox.Value;
        if isempty(varsToDel)
            setStatus('未选择要删除的变量，请先在右侧变量列表中多选。');
            return;
        end
        
        % 确认对话框
        answer = uiconfirm(fig, ...
            sprintf('即将从 %d 个文件中删除变量：\n%s\n\n操作将直接覆盖原文件，是否继续？', ...
            numel(files), strjoin(varsToDel, ', ')), ...
            '确认删除', ...
            'Options', {'继续', '取消'}, 'DefaultOption', 2);
        if ~strcmp(answer, '继续')
            return;
        end
        
        % 逐个文件处理
        setStatus('正在删除变量，请稍候...');
        drawnow;
        
        successCount = 0;
        failCount = 0;
        for i = 1:numel(files)
            filePath = files{i};
            try
                % 加载整个文件
                data = load(filePath);
                % 检查并删除指定变量
                deleted = {};
                for v = 1:numel(varsToDel)
                    var = varsToDel{v};
                    if isfield(data, var)
                        data = rmfield(data, var);
                        deleted{end+1} = var;
                    end
                end
                if isempty(deleted)
                    setStatus(sprintf('文件 %s 中未找到要删除的变量，跳过。', fileNames{i}));
                    continue;
                end
                % 保存回原文件
                save(filePath, '-struct', 'data');
                % 更新缓存：重新读取变量列表
                info = whos('-file', filePath);
                varsCache{i} = {info.name};
                successCount = successCount + 1;
                setStatus(sprintf('已从 %s 中删除：%s', fileNames{i}, strjoin(deleted, ', ')));
            catch ME
                failCount = failCount + 1;
                setStatus(sprintf('处理文件 %s 失败：%s', fileNames{i}, ME.message));
            end
        end
        
        % 如果当前选中的文件是刚刚修改过的，刷新其变量显示
        idx = getSelectedFileIndex();
        if ~isempty(idx)
            vars = varsCache{idx};
            varListBox.Items = vars;
            varListBox.Value = {};
        end
        
        setStatus(sprintf('删除完成。成功：%d 个文件，失败：%d 个文件。', successCount, failCount));
    end

    % -----------------------------------------------------------------
    % 辅助函数：获取当前选中的文件索引（fileListBox 中选中项对应的索引）
    function idx = getSelectedFileIndex()
        selectedName = fileListBox.Value;
        if isempty(selectedName)
            idx = [];
            return;
        end
        % 查找与选中显示名匹配的文件索引
        idx = find(strcmp(fileNames, selectedName), 1);
        if isempty(idx)
            idx = [];
        end
    end

    % -----------------------------------------------------------------
    % 辅助函数：获取用于显示的文件名（只取文件名，不含路径）
    function name = getDisplayName(fullPath)
        [~, name, ext] = fileparts(fullPath);
        name = [name ext];
    end

    % -----------------------------------------------------------------
    % 辅助函数：设置状态文本（自动换行，保留最近几条记录）
    function setStatus(msg)
        % 获取当前文本（可能多行）
        current = statusArea.Value;
        if ischar(current) || isstring(current)
            current = cellstr(current);
        end
        % 保留最近 5 条消息
        newMsg = [current; {msg}];
        if numel(newMsg) > 6
            newMsg = newMsg(end-5:end);
        end
        statusArea.Value = newMsg;
        drawnow;
    end

end