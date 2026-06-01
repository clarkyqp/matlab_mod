clear; close all;
run_scripts_ui();

function run_scripts_ui()
    % 创建主窗口
    fig = uifigure('Name', '脚本执行器（支持复选框选择）', ...
        'Position', [100 100 900 600], ...
        'Resize', 'on');

    mainGrid = uigridlayout(fig, [3, 1], ...
        'RowHeight', {'1x', '1x', 'fit'}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding', [10 10 10 10], ...
        'RowSpacing', 10);

    % 上部：文件列表区域（带复选框的表格）
    filePanel = uipanel(mainGrid, 'Title', '待执行脚本文件（勾选要运行的脚本）');
    fileGrid = uigridlayout(filePanel, [2, 1], ...
        'RowHeight', {'fit', '1x'}, ...
        'Padding', [5 5 5 5]);

    % 按钮行（并行模式改为复选框）
    btnGrid = uigridlayout(fileGrid, [1, 7], ...
        'ColumnWidth', {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', '1x'}, ...
        'Padding', [0 0 0 5]);
    addBtn = uibutton(btnGrid, 'push', 'Text', '添加脚本', ...
        'ButtonPushedFcn', @(btn,event) addFiles());
    removeBtn = uibutton(btnGrid, 'push', 'Text', '移除选中', ...
        'ButtonPushedFcn', @(btn,event) removeSelected());
    clearBtn = uibutton(btnGrid, 'push', 'Text', '清空列表', ...
        'ButtonPushedFcn', @(btn,event) clearList());
    saveCfgBtn = uibutton(btnGrid, 'push', 'Text', '保存配置', ...
        'ButtonPushedFcn', @(btn,event) saveConfig());
    selectAllBtn = uibutton(btnGrid, 'push', 'Text', '全选', ...
        'ButtonPushedFcn', @(btn,event) setAllCheckboxes(true));
    deselectAllBtn = uibutton(btnGrid, 'push', 'Text', '全不选', ...
        'ButtonPushedFcn', @(btn,event) setAllCheckboxes(false));
    
    % 并行模式复选框（取代原来的下拉菜单）
    parallelCheckBox = uicheckbox(btnGrid, ...
        'Text', '并行模式 (需Parallel Computing Toolbox，无图形界面)', ...
        'Value', false, ...
        'Tooltip', '勾选后使用batch并行执行，脚本中图形界面无法显示；不勾选则串行执行，支持图形窗口。');

    fileTable = uitable(fileGrid, ...
        'ColumnName', {'选择', '文件名', '完整路径'}, ...
        'ColumnWidth', {40, 180, 'auto'}, ...
        'ColumnEditable', [true, false, false], ...
        'Data', cell(0, 3), ...
        'FontSize', 10);

    % 中部：日志区域
    logPanel = uipanel(mainGrid, 'Title', '执行日志');
    logGrid = uigridlayout(logPanel, [1, 1], 'Padding', [5 5 5 5]);
    logArea = uitextarea(logGrid, ...
        'Editable', 'off', ...
        'Value', '就绪...', ...
        'FontSize', 10);

    % 底部：控制按钮
    controlGrid = uigridlayout(mainGrid, [1, 2], ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [0 0 0 0]);
    execBtn = uibutton(controlGrid, 'push', ...
        'Text', '开始执行（仅运行勾选脚本）', ...
        'ButtonPushedFcn', @(btn,event) executeScripts());
    stopBtn = uibutton(controlGrid, 'push', ...
        'Text', '终止执行', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(btn,event) stopExecution());

    % 存储数据
    scriptFiles = {};          % 绝对路径
    relativePaths = {};        % 相对路径
    stopExecutionFlag = false; % 终止标志
    futures = {};              % 并行作业句柄
    isParallelMode = false;    % 是否处于并行模式

    % 配置文件路径
    configDir = 'config';
    configFile = fullfile(configDir, 'script_list.json');

    % 辅助函数与目录
    ensureAuxiliaryFunction();
    ensureConfigDirExists();
    loadConfig();              % 加载配置并更新表格

    % ========== 辅助函数 ==========
    function ensureAuxiliaryFunction()
        if ~exist('runScriptAndReturn.m', 'file')
            fprintf('正在创建辅助函数 runScriptAndReturn.m ...\n');
            fid = fopen('runScriptAndReturn.m', 'w');
            fprintf(fid, 'function success = runScriptAndReturn(scriptPath)\n');
            fprintf(fid, '    try\n');
            fprintf(fid, '        [scriptDir, ~, ~] = fileparts(scriptPath);\n');
            fprintf(fid, '        oldPath = addpath(scriptDir);\n');
            fprintf(fid, '        cleanup = onCleanup(@() path(oldPath));\n');
            fprintf(fid, '        run(scriptPath);\n');
            fprintf(fid, '        success = true;\n');
            fprintf(fid, '    catch ME\n');
            fprintf(fid, '        fprintf(''错误：%%s\\n'', ME.message);\n');
            fprintf(fid, '        fprintf(''堆栈：\\n'');\n');
            fprintf(fid, '        for k = 1:length(ME.stack)\n');
            fprintf(fid, '            fprintf(''  在 %%s (行 %%d)\\n'', ME.stack(k).name, ME.stack(k).line);\n');
            fprintf(fid, '        end\n');
            fprintf(fid, '        success = false;\n');
            fprintf(fid, '    end\n');
            fprintf(fid, 'end\n');
            fclose(fid);
            fprintf('创建完成。\n');
        end
    end

    function ensureConfigDirExists()
        if ~exist(configDir, 'dir')
            mkdir(configDir);
            logMessage(sprintf('创建配置目录：%s', configDir));
        end
    end

    function loadConfig()
        if exist(configFile, 'file')
            try
                text = fileread(configFile);
                cfg = jsondecode(text);
                if isfield(cfg, 'relativePaths') && iscell(cfg.relativePaths)
                    rel = cfg.relativePaths(:)';
                    rel = rel(cellfun(@ischar, rel));
                    absPaths = cellfun(@(r) fullfile(pwd, r), rel, 'UniformOutput', false);
                    valid = cellfun(@(f) exist(f, 'file'), absPaths);
                    if ~all(valid)
                        missing = absPaths(~valid);
                        for k = 1:length(missing)
                            logMessage(sprintf('警告：配置文件中的文件不存在：%s', missing{k}));
                        end
                        absPaths = absPaths(valid);
                        rel = rel(valid);
                    end
                    scriptFiles = absPaths;
                    relativePaths = rel;
                    logMessage(sprintf('已从配置文件加载 %d 个脚本路径', length(scriptFiles)));
                else
                    logMessage('配置文件格式无效，使用空列表');
                    scriptFiles = {};
                    relativePaths = {};
                end
            catch ME
                logMessage(sprintf('读取配置文件失败：%s', ME.message));
                scriptFiles = {};
                relativePaths = {};
            end
        else
            logMessage('未找到配置文件，启动时使用空列表');
            scriptFiles = {};
            relativePaths = {};
        end
        updateFileTable();
    end

    function saveConfig()
        if isempty(relativePaths)
            selection = uiconfirm(fig, '当前脚本列表为空，是否仍要覆盖配置文件？', ...
                '确认保存', 'Options', {'是','否'}, 'DefaultOption',2);
            if strcmp(selection,'否'), return; end
        end
        try
            ensureConfigDirExists();
            cfg.relativePaths = relativePaths;
            jsonText = jsonencode(cfg, 'PrettyPrint', true);
            fid = fopen(configFile, 'w');
            if fid==-1, error('无法写入配置文件：%s', configFile); end
            fprintf(fid, '%s', jsonText);
            fclose(fid);
            logMessage(sprintf('配置已保存至 %s （共 %d 个脚本）', configFile, length(relativePaths)));
        catch ME
            logMessage(sprintf('保存配置失败：%s', ME.message));
            uialert(fig, ME.message, '保存错误');
        end
    end

    function addFiles()
        [files, path] = uigetfile('*.m', '选择MATLAB脚本文件', 'MultiSelect', 'on');
        if isequal(files,0), return; end
        if ischar(files), files = {files}; end
        newAbs = cellfun(@(f) fullfile(path,f), files, 'UniformOutput', false);
        currentDir = pwd;
        newRel = cellfun(@(absP) getRelativePath(absP, currentDir), newAbs, 'UniformOutput', false);
        scriptFiles = [scriptFiles, newAbs];
        relativePaths = [relativePaths, newRel];
        updateFileTable();
        logMessage(sprintf('已添加 %d 个脚本文件', length(newAbs)));
    end

    function rel = getRelativePath(absPath, baseDir)
        rel = strrep(absPath, [baseDir, filesep], '');
        if isequal(rel, absPath), rel = absPath; end
    end

    function removeSelected()
        data = fileTable.Data;
        if isempty(data), return; end
        selectedIdx = find([data{:,1}]);
        if isempty(selectedIdx)
            logMessage('未勾选任何文件，无法移除');
            return;
        end
        scriptFiles(selectedIdx) = [];
        relativePaths(selectedIdx) = [];
        updateFileTable();
        logMessage(sprintf('已移除 %d 个文件', length(selectedIdx)));
    end

    function clearList()
        scriptFiles = {};
        relativePaths = {};
        updateFileTable();
        logMessage('已清空文件列表');
    end

    function updateFileTable()
        n = length(scriptFiles);
        newData = cell(n, 3);
        for i = 1:n
            newData{i,1} = false;
            [~, name, ext] = fileparts(scriptFiles{i});
            newData{i,2} = [name, ext];
            newData{i,3} = scriptFiles{i};
        end
        fileTable.Data = newData;
        if n>0
            fileTable.Tooltip = sprintf('共 %d 个脚本', n);
        else
            fileTable.Tooltip = '无脚本';
        end
    end

    function setAllCheckboxes(checked)
        data = fileTable.Data;
        if isempty(data), return; end
        for i = 1:size(data,1)
            data{i,1} = checked;
        end
        fileTable.Data = data;
        if checked
            logMessage('已全选所有脚本');
        else
            logMessage('已取消全选');
        end
    end

    function name = getFileName(fullPath)
        [~, name, ext] = fileparts(fullPath);
        name = [name, ext];
    end

    function logMessage(msg)
        if ~isvalid(logArea)
            warning('日志区域无效，无法记录消息: %s', msg);
            return;
        end
        current = logArea.Value;
        if isempty(current) || (isstring(current) && current=="")
            logArea.Value = msg;
        else
            logArea.Value = [current; msg];
        end
        scroll(logArea, 'bottom');
    end

    function stopExecution()
        stopExecutionFlag = true;
        logMessage('用户请求终止执行...');
        if isParallelMode && ~isempty(futures)
            for i = 1:length(futures)
                if ~isempty(futures{i}) && isvalid(futures{i}) && strcmp(futures{i}.State, 'pending')
                    cancel(futures{i});
                    logMessage(sprintf('已取消脚本 %d 的作业', i));
                end
            end
        end
        stopBtn.Enable = 'off';
    end

    % ========== 执行入口 ==========
    function executeScripts()
        data = fileTable.Data;
        if isempty(data)
            logMessage('错误：请先添加脚本文件！');
            return;
        end
        selectedIdx = find([data{:,1}]);
        if isempty(selectedIdx)
            logMessage('错误：请至少勾选一个脚本！');
            return;
        end
        selectedFiles = scriptFiles(selectedIdx);
        
        stopExecutionFlag = false;
        execBtn.Enable = 'off';
        stopBtn.Enable = 'on';
        addBtn.Enable = 'off';
        removeBtn.Enable = 'off';
        clearBtn.Enable = 'off';
        saveCfgBtn.Enable = 'off';
        selectAllBtn.Enable = 'off';
        deselectAllBtn.Enable = 'off';
        parallelCheckBox.Enable = 'off';   % 执行期间禁止修改并行模式
        
        logMessage('========== 开始执行 ==========');
        logMessage(sprintf('本次共执行 %d 个脚本', length(selectedFiles)));
        
        % 获取并行模式选择（复选框）
        useParallel = parallelCheckBox.Value;
        hasParallel = license('test', 'Distrib_Computing_Toolbox') && exist('batch', 'file') == 2;
        
        if useParallel && hasParallel
            logMessage('使用 Parallel Computing Toolbox 并行执行（可随时终止，工作区完全隔离，但无法显示图形窗口）');
            isParallelMode = true;
            futures = cell(1, length(selectedFiles));
            for i = 1:length(selectedFiles)
                if stopExecutionFlag, break; end
                futures{i} = batch(@runScriptAndReturn, 1, {selectedFiles{i}});
            end
            monitorParallelExecution(selectedFiles);
        else
            if useParallel && ~hasParallel
                logMessage('警告：未检测到 Parallel Computing Toolbox，自动切换到串行模式。');
            else
                logMessage('使用串行模式执行（支持图形窗口，会短暂阻塞界面，可通过终止按钮停止后续脚本）。');
            end
            isParallelMode = false;
            runSerialWithStop(selectedFiles);
        end
        
        execBtn.Enable = 'on';
        stopBtn.Enable = 'off';
        addBtn.Enable = 'on';
        removeBtn.Enable = 'on';
        clearBtn.Enable = 'on';
        saveCfgBtn.Enable = 'on';
        selectAllBtn.Enable = 'on';
        deselectAllBtn.Enable = 'on';
        parallelCheckBox.Enable = 'on';
        futures = {};
        logMessage('========== 执行结束 ==========');
    end

    % 并行监视器
    function monitorParallelExecution(selectedFiles)
        n = length(futures);
        finished = false(1, n);
        while ~all(finished) && ~stopExecutionFlag
            pause(0.5);
            for i = 1:n
                if finished(i) || isempty(futures{i}) || ~isvalid(futures{i})
                    continue;
                end
                state = futures{i}.State;
                switch state
                    case 'finished'
                        try
                            result = fetchOutputs(futures{i});
                            if result{1}
                                logMessage(sprintf('✓ 脚本 %s 执行成功！', getFileName(selectedFiles{i})));
                            else
                                logMessage(sprintf('✗ 脚本 %s 执行失败！', getFileName(selectedFiles{i})));
                            end
                        catch ME
                            logMessage(sprintf('✗ 脚本 %s 执行失败：%s', getFileName(selectedFiles{i}), ME.message));
                        end
                        finished(i) = true;
                        delete(futures{i});
                    case 'failed'
                        logMessage(sprintf('✗ 脚本 %s 执行失败（作业崩溃）', getFileName(selectedFiles{i})));
                        try
                            err = getReport(futures{i}.Error);
                            logMessage(sprintf('   错误详情：%s', strtrim(err)));
                        catch
                            logMessage('   无法获取详细错误信息。');
                        end
                        finished(i) = true;
                        delete(futures{i});
                end
            end
            drawnow;
        end
        if stopExecutionFlag
            logMessage('正在终止所有未完成的脚本...');
            for i = 1:n
                if ~finished(i) && ~isempty(futures{i}) && isvalid(futures{i})
                    try
                        cancel(futures{i});
                        delete(futures{i});
                        logMessage(sprintf('已终止脚本 %s', getFileName(selectedFiles{i})));
                    catch
                    end
                end
            end
            logMessage('执行已被用户终止。');
        end
    end

    % 串行执行（支持图形界面，可中断后续脚本）
    function runSerialWithStop(selectedFiles)
        total = length(selectedFiles);
        for i = 1:total
            if stopExecutionFlag
                logMessage('检测到终止请求，停止执行剩余脚本。');
                break;
            end
            scriptPath = selectedFiles{i};
            scriptName = getFileName(scriptPath);
            logMessage(sprintf('\n>>> [%d/%d] 正在执行：%s', i, total, scriptName));
            drawnow;
            
            success = runScriptAndReturn(scriptPath);
            if success
                logMessage(sprintf('✓ 成功完成：%s', scriptName));
            else
                logMessage(sprintf('✗ 执行失败：%s', scriptName));
            end
        end
        if stopExecutionFlag
            logMessage('由于用户终止，部分脚本未执行。');
        end
    end
end