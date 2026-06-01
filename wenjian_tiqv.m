mat_copy_gui();
function mat_copy_gui()
    % 创建主窗口
    fig = uifigure('Name', '批量复制 .mat 文件（按名称匹配）', ...
                   'Position', [100 100 700 550], ...
                   'Resize', 'on');

    % 主网格布局：5行，列宽自适应
    mainGrid = uigridlayout(fig, [5, 1], ...
        'RowHeight', {'fit', 'fit', '1x', 'fit', 'fit'}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding', [10 10 10 10], ...
        'RowSpacing', 10);

    % ========== 1. 源文件夹选择区域 ==========
    folderPanel = uipanel(mainGrid, 'Title', '源文件夹');
    folderGrid = uigridlayout(folderPanel, [1, 3], ...
        'ColumnWidth', {'fit', '1x', 'fit'}, ...
        'Padding', [10 10 10 10]);
    uilabel(folderGrid, 'Text', '文件夹：');
    folderEdit = uieditfield(folderGrid, 'text', 'Editable', 'off');
    browseBtn = uibutton(folderGrid, 'push', 'Text', '浏览', ...
        'ButtonPushedFcn', @(btn,event) selectFolder());

    % ========== 2. 名称个数输入区域 ==========
    countPanel = uipanel(mainGrid, 'Title', '名称个数');
    countGrid = uigridlayout(countPanel, [1, 2], ...
        'ColumnWidth', {'fit', 'fit'}, ...
        'Padding', [10 10 10 10]);
    uilabel(countGrid, 'Text', '名称个数 n：');
    nEdit = uieditfield(countGrid, 'numeric', 'Value', 1, ...
        'ValueChangedFcn', @(src,event) updateNameInputs());

    % ========== 3. 名称列表区域（可滚动） ==========
    namePanel = uipanel(mainGrid, 'Title', '名称列表');
    nameGrid = uigridlayout(namePanel, [1, 1], ...
        'Scrollable', 'on', ...
        'Padding', [10 10 10 10], ...
        'RowHeight', {'fit'}, ...
        'ColumnWidth', {'1x'});
    nameEdits = [];  % 存储输入框句柄

    function updateNameInputs()
        n = round(nEdit.Value);
        if n < 1
            n = 1;
            nEdit.Value = 1;
        end
        delete(nameGrid.Children);
        nameEdits = gobjects(n, 1);
        for i = 1:n
            hBox = uigridlayout(nameGrid, [1, 2], ...
                'ColumnWidth', {70, '1x'}, ...
                'Padding', [0 0 0 0]);
            uilabel(hBox, 'Text', sprintf('名称 %d：', i));
            nameEdits(i) = uieditfield(hBox, 'text');
        end
    end
    updateNameInputs();

    % ========== 4. 按钮区域 ==========
    btnPanel = uipanel(mainGrid, 'Title', '');  % 无标题面板仅用于放置按钮
    btnGrid = uigridlayout(btnPanel, [1, 2], ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [10 10 10 10]);
    processBtn = uibutton(btnGrid, 'push', 'Text', '开始匹配与复制', ...
        'ButtonPushedFcn', @(btn,event) process());
    clearLogBtn = uibutton(btnGrid, 'push', 'Text', '清空日志', ...
        'ButtonPushedFcn', @(btn,event) clearLog());

    % ========== 5. 日志显示区域 ==========
    logPanel = uipanel(mainGrid, 'Title', '处理日志');
    logGrid = uigridlayout(logPanel, [1, 1], 'Padding', [5 5 5 5]);
    logArea = uitextarea(logGrid, 'Editable', 'off', 'Value', '就绪...');

    % 全局变量
    srcFolder = '';

    % 回调函数
    function selectFolder()
        folder = uigetdir(pwd, '请选择包含 .mat 文件的文件夹');
        if isequal(folder, 0); return; end
        srcFolder = folder;
        folderEdit.Value = srcFolder;
        logMessage(sprintf('已选择源文件夹：%s', srcFolder));
    end

    function clearLog()
        logArea.Value = '';
    end

    function logMessage(msg)
        current = logArea.Value;
        if isempty(current)
            logArea.Value = msg;
        else
            logArea.Value = [current; msg];
        end
        scroll(logArea, 'bottom');
    end

    function process()
        % 检查源文件夹
        if isempty(srcFolder)
            logMessage('错误：请先选择源文件夹！');
            return;
        end
        % 获取名称个数
        n = round(nEdit.Value);
        if n < 1
            logMessage('错误：名称个数必须为正整数！');
            return;
        end
        % 获取名称列表
        names = cell(n, 1);
        for i = 1:n
            names{i} = strtrim(nameEdits(i).Value);
            if isempty(names{i})
                logMessage(sprintf('错误：名称 %d 不能为空！', i));
                return;
            end
        end
        logMessage(sprintf('共 %d 个名称：%s', n, strjoin(names, ', ')));

        % 获取源文件夹下所有 .mat 文件
        matFiles = dir(fullfile(srcFolder, '*.mat'));
        if isempty(matFiles)
            logMessage('错误：所选文件夹下没有 .mat 文件！');
            return;
        end
        logMessage(sprintf('找到 %d 个 .mat 文件。', length(matFiles)));

        % ★★★ 根据名称列表生成输出文件夹名（用下划线连接）★★★
        folderName = strjoin(names, '_');
        % 移除可能导致问题的非法字符（可选，但保留原样通常没问题）
        % folderName = regexprep(folderName, '[<>:"/\\|?*]', '_');  % 根据需要启用
        outputFolder = fullfile(srcFolder, folderName);
        
        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder);
            logMessage(sprintf('已创建输出文件夹：%s', outputFolder));
        else
            logMessage(sprintf('输出文件夹已存在：%s', outputFolder));
        end

        % 预先统计所有需要复制的文件（用于进度条）
        allMatches = {};
        for i = 1:n
            keyword = names{i};
            idx = contains({matFiles.name}, keyword);
            matchedFiles = matFiles(idx);
            for k = 1:length(matchedFiles)
                allMatches{end+1} = matchedFiles(k).name;
            end
        end
        totalFiles = length(allMatches);
        if totalFiles == 0
            logMessage('未找到任何匹配的文件，处理结束。');
            return;
        end
        logMessage(sprintf('共匹配到 %d 个文件，开始复制...', totalFiles));

        % 创建进度条
        dlg = uiprogressdlg(fig, 'Title', '正在复制', ...
                                 'Message', '准备复制...', ...
                                 'Indeterminate', 'off', ...
                                 'Cancelable', 'on');
        dlg.Value = 0;

        successCount = 0;
        processed = 0;

        % 逐个名称处理
        for i = 1:n
            keyword = names{i};
            idx = contains({matFiles.name}, keyword);
            candidateFiles = matFiles(idx);
            if isempty(candidateFiles)
                logMessage(sprintf('跳过：未找到包含关键词 "%s" 的文件。', keyword));
                continue;
            end

            logMessage(sprintf('关键词 "%s" 匹配到 %d 个文件。', keyword, length(candidateFiles)));

            for j = 1:length(candidateFiles)
                fileToCopy = candidateFiles(j).name;
                srcFile = fullfile(srcFolder, fileToCopy);
                dstFile = fullfile(outputFolder, fileToCopy);
                [success, msg] = copyfile(srcFile, dstFile);
                if success
                    logMessage(sprintf('已复制：%s -> %s', fileToCopy, fullfile(folderName, fileToCopy)));
                    successCount = successCount + 1;
                else
                    logMessage(sprintf('复制文件 %s 失败：%s', srcFile, msg));
                end

                processed = processed + 1;
                dlg.Value = processed / totalFiles;
                dlg.Message = sprintf('正在复制 %d/%d 个文件...', processed, totalFiles);

                if dlg.CancelRequested
                    logMessage('用户取消复制操作。');
                    close(dlg);
                    return;
                end
            end
        end

        close(dlg);
        logMessage(sprintf('处理完成！共成功复制 %d 个文件。', successCount));
    end
end