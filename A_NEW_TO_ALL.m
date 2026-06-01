replaceSameNameFiles();
function replaceSameNameFiles()
% replaceSameNameFiles - 带UI界面的多文件批量替换工具（兼容旧版MATLAB，修复waitbar警告）
%
% 功能：
%   1. 支持一次性选择多个新版本文件（源文件）
%   2. 支持选择根目录，递归查找并替换所有子文件夹中的同名文件
%   3. 自动保存/加载上次使用的源文件列表和根目录到 config 文件夹
%   4. 提供图形界面，可手动修改路径或直接使用上次配置
%   5. 执行前展示详细替换清单，用户确认后批量替换，并显示进度与结果

    %% 创建传统UI界面（兼容R2014a及更早）
    fig = figure('Name', '同名文件批量替换工具', ...
                 'Position', [300, 300, 650, 400], ...
                 'NumberTitle', 'off', ...
                 'MenuBar', 'none', ...
                 'ToolBar', 'none', ...
                 'Resize', 'on');
    
    % 存储数据的结构体（通过 guidata 共享）
    data = struct();
    data.srcFiles = {};       % 源文件完整路径 cell
    data.rootDir = '';        % 根目录路径
    data.fig = fig;
    
    % 配置文件路径
    scriptDir = fileparts(mfilename('fullpath'));
    configDir = fullfile(scriptDir, 'config');
    if ~exist(configDir, 'dir')
        mkdir(configDir);
    end
    data.configFile = fullfile(configDir, 'A_NEW_TO_ALL_config.mat');
    
    % 创建控件
    % 源文件区域
    uicontrol('Style', 'text', 'String', '源文件列表（可多选）：', ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold', ...
              'Position', [20, 340, 200, 20]);
    uicontrol('Style', 'pushbutton', 'String', '选择源文件', ...
              'Position', [520, 335, 100, 30], ...
              'Callback', @(~,~) selectSourceFiles());
    
    data.srcListBox = uicontrol('Style', 'listbox', ...
                                'Position', [20, 200, 600, 130], ...
                                'Max', 2, 'Min', 0, ...
                                'String', {'(未选择任何源文件)'}, ...
                                'Value', 1);
    
    % 根目录区域
    uicontrol('Style', 'text', 'String', '根目录（递归搜索）：', ...
              'HorizontalAlignment', 'left', 'FontWeight', 'bold', ...
              'Position', [20, 170, 200, 20]);
    uicontrol('Style', 'pushbutton', 'String', '选择根目录', ...
              'Position', [520, 165, 100, 30], ...
              'Callback', @(~,~) selectRootDir());
    
    data.rootEdit = uicontrol('Style', 'edit', ...
                              'Position', [20, 135, 600, 25], ...
                              'HorizontalAlignment', 'left', ...
                              'Enable', 'inactive', ...
                              'BackgroundColor', [1,1,1]);
    
    % 按钮区域
    uicontrol('Style', 'pushbutton', 'String', '加载上次配置', ...
              'Position', [20, 80, 120, 35], ...
              'Callback', @(~,~) loadLastConfig());
    uicontrol('Style', 'pushbutton', 'String', '保存当前配置', ...
              'Position', [160, 80, 120, 35], ...
              'Callback', @(~,~) saveCurrentConfig());
    uicontrol('Style', 'pushbutton', 'String', '开始替换', ...
              'Position', [500, 80, 120, 35], ...
              'BackgroundColor', [0.7, 1, 0.7], ...
              'Callback', @(~,~) startReplacement());
    
    % 将数据保存到 figure 中
    guidata(fig, data);
    
    % 自动加载上次配置（如果存在）
    loadLastConfig(true);  % 静默加载
    
    %% ----------------------------------------------------------------
    % 以下为嵌套函数，可以共享 data 结构体（通过 guidata 读取/写入）
    %% ----------------------------------------------------------------
    
    function updateUI()
        data = guidata(fig);
        % 更新源文件列表框
        if ~isempty(data.srcFiles)
            % 显示带路径缩写的文件名
            displayItems = cellfun(@(f) getShortDisplayName(f), data.srcFiles, 'UniformOutput', false);
            set(data.srcListBox, 'String', displayItems, 'Value', 1);
        else
            set(data.srcListBox, 'String', {'(未选择任何源文件)'}, 'Value', 1);
        end
        % 更新根目录编辑框
        if ~isempty(data.rootDir)
            set(data.rootEdit, 'String', data.rootDir);
        else
            set(data.rootEdit, 'String', '');
        end
        guidata(fig, data);
    end
    
    function shortName = getShortDisplayName(fullPath)
        [fdir, fname, fext] = fileparts(fullPath);
        [~, lastDir] = fileparts(fdir);
        if ~isempty(lastDir)
            shortName = [lastDir, filesep, fname, fext];
        else
            shortName = [fname, fext];
        end
    end
    
    %% 回调：选择源文件（多选）
    function selectSourceFiles()
        data = guidata(fig);
        [fileNames, pathName] = uigetfile('*.*', '请选择一个或多个新版本文件', ...
                                          'MultiSelect', 'on');
        if isequal(fileNames, 0)
            return;
        end
        if ischar(fileNames)
            fileNames = {fileNames};
        end
        newFiles = cellfun(@(f) fullfile(pathName, f), fileNames, 'UniformOutput', false);
        
        % 去重（按完整路径）
        [~, uniqueIdx] = unique(cellfun(@(f) lower(f), newFiles, 'UniformOutput', false), 'stable');
        if length(uniqueIdx) < length(newFiles)
            warndlg('检测到重复的源文件（同名），已自动去重', '重复文件提示');
            newFiles = newFiles(uniqueIdx);
        end
        
        data.srcFiles = newFiles;
        guidata(fig, data);
        updateUI();
    end
    
    %% 回调：选择根目录
    function selectRootDir()
        data = guidata(fig);
        dirPath = uigetdir(cd, '请选择要搜索并替换同名文件的根目录');
        if isequal(dirPath, 0)
            return;
        end
        data.rootDir = dirPath;
        guidata(fig, data);
        updateUI();
    end
    
    %% 保存当前配置
    function saveCurrentConfig()
        data = guidata(fig);
        if isempty(data.srcFiles) && isempty(data.rootDir)
            errordlg('没有可保存的配置（源文件或根目录为空）', '保存失败');
            return;
        end
        configData = struct('srcFiles', {data.srcFiles}, 'rootDir', data.rootDir);
        try
            save(data.configFile, '-struct', 'configData');
            msgbox('配置已保存到 config 文件夹', '保存成功');
        catch ME
            errordlg(['保存失败：' ME.message], '错误');
        end
    end
    
    %% 加载上次配置
    function loadLastConfig(silent)
        if nargin < 1, silent = false; end
        data = guidata(fig);
        if ~exist(data.configFile, 'file')
            if ~silent
                errordlg('未找到上次保存的配置文件', '加载失败');
            end
            return;
        end
        try
            saved = load(data.configFile);
            if isfield(saved, 'srcFiles') && iscell(saved.srcFiles)
                existIdx = cellfun(@(f) exist(f, 'file') == 2, saved.srcFiles);
                if any(~existIdx)
                    if ~silent
                        warndlg(sprintf('以下源文件已不存在，将被忽略：\n%s', ...
                            strjoin(saved.srcFiles(~existIdx), '\n')), '部分文件缺失');
                    end
                    saved.srcFiles = saved.srcFiles(existIdx);
                end
                data.srcFiles = saved.srcFiles;
            else
                data.srcFiles = {};
            end
            if isfield(saved, 'rootDir') && exist(saved.rootDir, 'dir')
                data.rootDir = saved.rootDir;
            else
                data.rootDir = '';
                if isfield(saved, 'rootDir') && ~isempty(saved.rootDir) && ~silent
                    warndlg('上次保存的根目录已不存在，请重新选择', '路径无效');
                end
            end
            guidata(fig, data);
            updateUI();
            if ~silent
                msgbox('已加载上次配置', '加载成功');
            end
        catch ME
            if ~silent
                errordlg(['加载配置失败：' ME.message], '错误');
            end
        end
    end
    
    %% 开始替换主逻辑
    function startReplacement()
        data = guidata(fig);
        if isempty(data.srcFiles)
            errordlg('请先选择源文件', '缺少源文件');
            return;
        end
        if isempty(data.rootDir) || ~exist(data.rootDir, 'dir')
            errordlg('请选择有效的根目录', '根目录无效');
            return;
        end
        
        % 检查所有源文件是否存在
        missingIdx = cellfun(@(f) exist(f, 'file') ~= 2, data.srcFiles);
        if any(missingIdx)
            errordlg(sprintf('以下源文件不存在：\n%s', strjoin(data.srcFiles(missingIdx), '\n')), ...
                     '文件缺失');
            return;
        end
        
        % 获取所有待替换的目标文件
        replacementMap = containers.Map();
        totalTargets = 0;
        allReplacements = {};
        
        for i = 1:length(data.srcFiles)
            src = data.srcFiles{i};
            [~, srcNameNoExt, srcExt] = fileparts(src);
            srcFullName = [srcNameNoExt, srcExt];
            
            allFiles = getAllFiles(data.rootDir);
            targetList = {};
            for j = 1:length(allFiles)
                [~, tName, tExt] = fileparts(allFiles{j});
                tFullName = [tName, tExt];
                if strcmpi(tFullName, srcFullName) && ~strcmp(allFiles{j}, src)
                    targetList{end+1} = allFiles{j};
                end
            end
            
            if ~isempty(targetList)
                replacementMap(src) = targetList;
                totalTargets = totalTargets + length(targetList);
                for k = 1:length(targetList)
                    allReplacements{end+1, 1} = src;
                    allReplacements{end, 2} = targetList{k};
                end
            end
        end
        
        if totalTargets == 0
            errordlg('在所选根目录下没有找到任何与源文件同名的文件', '无匹配文件');
            return;
        end
        
        % 显示确认对话框
        confirmMsg = sprintf('共找到 %d 个待替换的文件（涉及 %d 个源文件）：\n\n', ...
                             totalTargets, length(data.srcFiles));
        for i = 1:length(data.srcFiles)
            src = data.srcFiles{i};
            if replacementMap.isKey(src)
                targets = replacementMap(src);
                [~, shortSrcName] = fileparts(src);
                confirmMsg = [confirmMsg, sprintf('■ %s  →  %d 个同名文件\n', ...
                            shortSrcName, length(targets))];
                for t = 1:min(3, length(targets))
                    [tPath, tName, tExt] = fileparts(targets{t});
                    [~, lastDir] = fileparts(tPath);
                    shortTarget = fullfile(lastDir, [tName, tExt]);
                    confirmMsg = [confirmMsg, sprintf('     - %s\n', shortTarget)];
                end
                if length(targets) > 3
                    confirmMsg = [confirmMsg, sprintf('     ... 等共 %d 个\n', length(targets))];
                end
                confirmMsg = [confirmMsg, '\n'];
            end
        end
        confirmMsg = [confirmMsg, '是否确认执行替换？\n（原文件将被覆盖，请确保已备份）'];
        
        choice = questdlg(confirmMsg, '确认替换操作', '确认替换', '取消', '取消');
        if ~strcmp(choice, '确认替换')
            return;
        end
        
        % 执行替换（带进度条，修复反斜杠警告）
        hWait = waitbar(0, '正在替换文件，请稍候...', 'Name', '批量替换进度');
        successCount = 0;
        failList = {};
        
        for i = 1:size(allReplacements, 1)
            srcFile = allReplacements{i, 1};
            targetFile = allReplacements{i, 2};
            % 修复：将路径中的单反斜杠替换为双反斜杠，避免 TeX 解释器警告
            safeTarget = strrep(targetFile, '\', '\\');
            waitbar(i / size(allReplacements, 1), hWait, ...
                    sprintf('正在替换：%s', safeTarget));
            try
                copyfile(srcFile, targetFile, 'f');
                successCount = successCount + 1;
                fprintf('[成功] %s\n', targetFile);
            catch ME
                failList{end+1} = targetFile;
                fprintf('[失败] %s - 原因：%s\n', targetFile, ME.message);
            end
        end
        
        close(hWait);
        
        if isempty(failList)
            msgbox(sprintf('替换完成！\n成功替换 %d 个文件。', successCount), '完成');
        else
            msgbox(sprintf('替换完成，但发生错误：\n成功：%d 个\n失败：%d 个\n失败列表已显示在命令窗口。', ...
                          successCount, length(failList)), '部分失败', 'warn');
            disp('失败的文件列表：');
            disp(failList);
        end
    end

end

%% 辅助函数：递归获取某目录下所有文件的绝对路径
function fileList = getAllFiles(rootDir)
    fileList = {};
    items = dir(rootDir);
    items = items(~ismember({items.name}, {'.', '..'}));
    
    for i = 1:length(items)
        fullPath = fullfile(rootDir, items(i).name);
        if items(i).isdir
            subFiles = getAllFiles(fullPath);
            fileList = [fileList, subFiles];
        else
            fileList{end+1} = fullPath;
        end
    end
end