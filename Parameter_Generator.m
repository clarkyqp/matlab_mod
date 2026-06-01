clear; close all;
parameterGeneratorUI();
function parameterGeneratorUI()
    % 参数生成器UI - 支持动态添加参数，为每个参数指定多个取值，选择需要的值并生成输出
    % 创建图形窗口
    fig = uifigure('Name', '参数生成器', 'Position', [100, 100, 1000, 700], 'Resize', 'on');
    
    % ==================== 数据存储 ====================
    paramsData = struct('name', {}, 'allValues', {}, 'selectedValues', {});
    
    % 预设示例数据
    defaultParams = struct();
    defaultParams(1).name = 'threshold_list';
    defaultParams(1).allValues = [15];
    defaultParams(1).selectedValues = [15];
    defaultParams(2).name = 'N_fft_list';
    defaultParams(2).allValues = [512, 1024, 2048, 4096];
    defaultParams(2).selectedValues = [512, 1024, 2048, 4096];
    defaultParams(3).name = 'window_list';
    defaultParams(3).allValues = {'kaiser', 'hanning', 'hamming', 'blackman', 'none'};
    defaultParams(3).selectedValues = {'kaiser', 'hanning', 'hamming', 'blackman', 'none'};
    defaultParams(4).name = 'coeff_list';
    defaultParams(4).allValues = [0, 0.2, 0.4, 0.6, 0.8, 1];
    defaultParams(4).selectedValues = [0, 0.2, 0.4, 0.6, 0.8, 1];
    
    % ==================== 配置文件夹路径（默认路径） ====================
    configDir = fullfile(pwd, 'config');
    defaultConfigFile = fullfile(configDir, 'params_config.mat');
    
    % 尝试从默认配置文件加载，否则使用默认参数
    if exist(defaultConfigFile, 'file')
        try
            loaded = load(defaultConfigFile);
            if isfield(loaded, 'paramsData') && ~isempty(loaded.paramsData)
                paramsData = loaded.paramsData;
            else
                paramsData = defaultParams;
            end
        catch
            paramsData = defaultParams;
        end
    else
        paramsData = defaultParams;
    end
    
    % ==================== UI 组件布局 ====================
    mainGrid = uigridlayout(fig, [2, 1], 'RowHeight', {'fit', '1x'}, 'Padding', [10, 10, 10, 10]);
    
    controlPanel = uigridlayout(mainGrid, [1, 6], 'ColumnWidth', {'fit', 'fit', 'fit', 'fit', 'fit', '1x'}, ...
        'Padding', [5, 5, 5, 5], 'RowHeight', {'fit'});
    
    uilabel(controlPanel, 'Text', '参数个数 N:', 'FontSize', 12, 'FontWeight', 'bold');
    nEditField = uieditfield(controlPanel, 'numeric', 'Value', length(paramsData), 'Limits', [1, 50], ...
        'ValueDisplayFormat', '%.0f', 'FontSize', 12);
    refreshBtn = uibutton(controlPanel, 'Text', '刷新参数面板', 'ButtonPushedFcn', @(btn,event) refreshParamPanel(), 'FontSize', 12);
    saveBtn = uibutton(controlPanel, 'Text', '保存配置', 'ButtonPushedFcn', @(btn,event) saveConfig(), 'FontSize', 12);
    loadBtn = uibutton(controlPanel, 'Text', '加载配置', 'ButtonPushedFcn', @(btn,event) loadConfig(), 'FontSize', 12);
    genBtn = uibutton(controlPanel, 'Text', '生成输出', 'ButtonPushedFcn', @(btn,event) generateOutput(), 'FontSize', 12, 'BackgroundColor', [0.8, 0.9, 1]);
    
    scrollPanel = uipanel(mainGrid, 'Title', '参数配置 (每个参数可设置名称、取值列表，点击"选择值"按钮选取需要的值)', 'FontSize', 12, 'FontWeight', 'bold');
    paramGrid = uigridlayout(scrollPanel, [1, 1], 'Scrollable', 'on', 'Padding', [10, 10, 10, 10]);
    
    outputPanel = uipanel(mainGrid, 'Title', '生成结果 (MATLAB赋值语句)', 'FontSize', 12, 'FontWeight', 'bold');
    outputGrid = uigridlayout(outputPanel, [2, 1], 'RowHeight', {'1x', 'fit'}, 'Padding', [5, 5, 5, 5]);
    outputTextArea = uitextarea(outputGrid, 'Value', '', 'Editable', 'off', 'FontName', 'Consolas', 'FontSize', 11);
    copyBtn = uibutton(outputGrid, 'Text', '复制到剪贴板', 'ButtonPushedFcn', @(btn,event) copyOutputToClipboard(), 'FontSize', 11);
    
    % ==================== 辅助函数 ====================
    function ensureConfigDir()
        if ~exist(configDir, 'dir')
            mkdir(configDir);
        end
    end
    
    function str = formatNumericArrayWithCommas(arr)
        if isempty(arr)
            str = '[]';
            return;
        end
        strParts = cell(1, length(arr));
        for i = 1:length(arr)
            strParts{i} = num2str(arr(i));
        end
        str = ['[' strjoin(strParts, ', ') ']'];
    end
    
    function [values, isValid] = parseValuesFromString(str)
        str = strtrim(str);
        isValid = false;
        values = [];
        if isempty(str), return; end
        
        numVec = str2num(str); %#ok<ST2NM>
        if ~isempty(numVec) && isnumeric(numVec)
            values = numVec;
            isValid = true;
            return;
        end
        
        if (str(1) == '''' && str(end) == '''') || (str(1) == '"' && str(end) == '"')
            values = {strip(str, '''"')};
            isValid = true;
            return;
        end
        
        try
            evaluated = eval(str);
            if iscellstr(evaluated) || (iscell(evaluated) && all(cellfun(@ischar, evaluated))) %#ok<ISCLSTR>
                values = evaluated;
                isValid = true;
                return;
            end
        catch
        end
        
        if contains(str, ',')
            parts = strsplit(str, ',');
            parts = strtrim(parts);
            for i = 1:length(parts)
                parts{i} = strip(parts{i}, '''"');
            end
            values = parts;
            isValid = true;
            return;
        end
        
        uialert(fig, ['无法解析取值列表: ' str], '解析错误', 'Icon', 'warning');
    end
    
    function str = formatValuesSummary(values)
        if isempty(values)
            str = '(无)';
            return;
        end
        if isnumeric(values)
            if length(values) <= 5
                str = formatNumericArrayWithCommas(values);
            else
                str = [formatNumericArrayWithCommas(values(1:3)), ' ... ', formatNumericArrayWithCommas(values(end-2:end))];
            end
        elseif iscellstr(values) || iscell(values)
            if length(values) <= 3
                parts = cellfun(@(x) ['''' x ''''], values, 'UniformOutput', false);
                str = ['{' strjoin(parts, ', ') '}'];
            else
                first = ['''' values{1} ''''];
                last = ['''' values{end} ''''];
                str = ['{' first ', ... , ' last '}'];
            end
        else
            str = '?';
        end
    end
    
    function updateParamName(idx, newName)
        if ~isempty(strtrim(newName))
            paramsData(idx).name = newName;
        end
    end
    
    function refreshParamPanel()
        N = round(nEditField.Value);
        if N < 1, N = 1; nEditField.Value = 1; end
        
        currentN = length(paramsData);
        if N > currentN
            for i = currentN+1:N
                newParam.name = ['param', num2str(i)];
                newParam.allValues = [1,2,3];
                newParam.selectedValues = [1,2,3];
                paramsData = [paramsData, newParam];
            end
        elseif N < currentN
            paramsData = paramsData(1:N);
        end
        
        delete(allchild(paramGrid));
        paramGrid.RowHeight = repmat({'fit'}, 1, N);
        paramGrid.ColumnWidth = {'1.2x', '2.5x', '0.8x', '0.8x', '1.5x'};
        
        headerLabels = {'参数名', '取值列表 (输入格式如 [1,2,3] 或 {''a'',''b''})', '更新值', '选择值', '当前选中值'};
        for col = 1:5
            uilabel(paramGrid, 'Text', headerLabels{col}, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontSize', 11);
        end
        
        for i = 1:N
            nameEdit = uieditfield(paramGrid, 'text', 'Value', paramsData(i).name, 'HorizontalAlignment', 'left', 'FontSize', 11);
            nameEdit.ValueChangedFcn = @(src,~) updateParamName(i, src.Value);
            
            if isnumeric(paramsData(i).allValues)
                valStr = formatNumericArrayWithCommas(paramsData(i).allValues);
            else
                parts = cellfun(@(x) ['''' x ''''], paramsData(i).allValues, 'UniformOutput', false);
                valStr = ['{' strjoin(parts, ', ') '}'];
            end
            valEdit = uieditfield(paramGrid, 'text', 'Value', valStr, 'FontSize', 11);
            
            uibutton(paramGrid, 'Text', '更新', 'ButtonPushedFcn', @(btn,~) updateParamValues(i, valEdit.Value), 'FontSize', 11);
            uibutton(paramGrid, 'Text', '选择值', 'ButtonPushedFcn', @(btn,~) selectValuesForParam(i), 'FontSize', 11);
            
            summaryStr = formatValuesSummary(paramsData(i).selectedValues);
            uilabel(paramGrid, 'Text', summaryStr, 'FontSize', 10, 'HorizontalAlignment', 'left', 'WordWrap', 'on');
        end
    end
    
    function updateParamValues(idx, valString)
        [newValues, isValid] = parseValuesFromString(valString);
        if isValid
            paramsData(idx).allValues = newValues;
            paramsData(idx).selectedValues = newValues;
            refreshParamPanel();
        else
            uialert(fig, ['参数 "' paramsData(idx).name '" 取值列表格式错误，未更新。'], '格式错误', 'Icon', 'error');
        end
    end
    
    function selectValuesForParam(idx)
        allVals = paramsData(idx).allValues;
        if isempty(allVals)
            uialert(fig, ['参数 "' paramsData(idx).name '" 没有可用的取值，请先更新取值列表。'], '无可用值', 'Icon', 'warning');
            return;
        end
        
        if isnumeric(allVals)
            items = arrayfun(@(x) num2str(x), allVals, 'UniformOutput', false);
        else
            items = allVals;
        end
        
        if isnumeric(paramsData(idx).selectedValues)
            [~, selectedIndices] = ismember(paramsData(idx).selectedValues, allVals);
            selectedIndices = selectedIndices(selectedIndices > 0);
        else
            [~, selectedIndices] = ismember(paramsData(idx).selectedValues, allVals);
            selectedIndices = selectedIndices(selectedIndices > 0);
        end
        
        [indices, ok] = listdlg('ListString', items, 'SelectionMode', 'multiple', ...
            'InitialValue', selectedIndices, 'Name', ['选择 ' paramsData(idx).name ' 需要的值'], ...
            'PromptString', '请选择需要包含的值 (可多选):', 'ListSize', [300, 200]);
        
        if ok && ~isempty(indices)
            if isnumeric(allVals)
                paramsData(idx).selectedValues = allVals(indices);
            else
                paramsData(idx).selectedValues = allVals(indices);
            end
            refreshParamPanel();
        end
    end
    
    % 保存配置 - 直接保存到默认路径，不弹出文件选择对话框
    function saveConfig()
        ensureConfigDir();
        try
            save(defaultConfigFile, 'paramsData');
            uialert(fig, ['配置已保存至: ' defaultConfigFile], '保存成功', 'Icon', 'success');
        catch ME
            uialert(fig, ['保存失败: ' ME.message], '错误', 'Icon', 'error');
        end
    end
    
    % 加载配置 - 直接从默认路径加载，不弹出文件选择对话框
    function loadConfig()
        if ~exist(defaultConfigFile, 'file')
            uialert(fig, ['默认配置文件不存在: ' defaultConfigFile], '加载失败', 'Icon', 'warning');
            return;
        end
        try
            data = load(defaultConfigFile);
            if isfield(data, 'paramsData')
                paramsData = data.paramsData;
                nEditField.Value = length(paramsData);
                refreshParamPanel();
                uialert(fig, '配置加载成功', '加载成功', 'Icon', 'success');
            else
                uialert(fig, '配置文件中未找到有效的 paramsData 变量', '加载失败', 'Icon', 'error');
            end
        catch ME
            uialert(fig, ['加载失败: ' ME.message], '错误', 'Icon', 'error');
        end
    end
    
    function generateOutput()
        outputLines = {};
        for i = 1:length(paramsData)
            paramName = paramsData(i).name;
            if ~isvarname(paramName)
                paramName = matlab.lang.makeValidName(paramName);
                uialert(fig, ['参数名 "' paramsData(i).name '" 已自动转换为有效变量名: ' paramName], '变量名修正', 'Icon', 'warning');
            end
            
            selected = paramsData(i).selectedValues;
            if isempty(selected)
                selected = paramsData(i).allValues;
                if isempty(selected), continue; end
            end
            
            if isnumeric(selected)
                valueStr = formatNumericArrayWithCommas(selected);
            elseif iscell(selected)
                parts = cellfun(@(x) ['''' x ''''], selected, 'UniformOutput', false);
                valueStr = ['{' strjoin(parts, ', ') '}'];
            else
                continue;
            end
            
            outputLines{end+1} = [paramName ' = ' valueStr ';'];
        end
        
        if isempty(outputLines)
            outputTextArea.Value = { '% 没有生成任何输出，请检查参数配置。' };
        else
            outputTextArea.Value = outputLines;
        end
    end
    
    function copyOutputToClipboard()
        currentOutput = outputTextArea.Value;
        if isempty(currentOutput) || (ischar(currentOutput) && isempty(currentOutput))
            uialert(fig, '没有可复制的内容，请先生成输出。', '无内容', 'Icon', 'info');
            return;
        end
        if iscell(currentOutput)
            clipText = strjoin(currentOutput, '\n');
        else
            clipText = currentOutput;
        end
        clipboard('copy', clipText);
        uialert(fig, '已复制到剪贴板', '复制成功', 'Icon', 'success');
    end
    
    % ==================== 初始化 ====================
    refreshParamPanel();
end