clear; close all;
linear_fit_ui()
function linear_fit_ui()
    % 创建主窗口
    fig = uifigure('Name', '线性回归拟合', 'Position', [300 300 500 400]);
    
    % 创建网格布局
    mainGrid = uigridlayout(fig, [4, 2], 'RowHeight', {30, 30, '1x', 40}, 'ColumnWidth', {'1x', '1x'});
    
    % 第1行：点个数输入
    lblN = uilabel(mainGrid, 'Text', '点的个数 N：', 'HorizontalAlignment', 'right');
    lblN.Layout.Row = 1; lblN.Layout.Column = 1;
    % 修正：初始值设为1，满足Limits范围 [1, inf]
    editN = uieditfield(mainGrid, 'numeric', 'Value', 1, 'Limits', [1, inf]);
    editN.Layout.Row = 1; editN.Layout.Column = 2;
    
    % 第2行：生成表格按钮
    btnGen = uibutton(mainGrid, 'push', 'Text', '生成数据表格', 'ButtonPushedFcn', @(btn,event) generateTable());
    btnGen.Layout.Row = 2; btnGen.Layout.Column = [1,2];
    
    % 第3行：表格占位
    tbl = uitable(mainGrid, 'ColumnName', {'x', 'y'}, 'ColumnEditable', [true, true]);
    tbl.Layout.Row = 3; tbl.Layout.Column = [1,2];
    
    % 第4行：拟合按钮和结果显示
    btnFit = uibutton(mainGrid, 'push', 'Text', '执行线性拟合', 'ButtonPushedFcn', @(btn,event) fitAndPlot());
    btnFit.Layout.Row = 4; btnFit.Layout.Column = 1;
    lblResult = uilabel(mainGrid, 'Text', '', 'HorizontalAlignment', 'left');
    lblResult.Layout.Row = 4; lblResult.Layout.Column = 2;
    
    % 存储数据（实际上直接使用表格数据，此处可省略）
    function generateTable()
        N = round(editN.Value);
        if N < 1
            uialert(fig, '点的个数必须 ≥ 1', '输入错误');
            return;
        end
        % 创建空表格数据（N行2列），初始为NaN
        tblData = nan(N, 2);
        tbl.Data = tblData;
    end
    
    function fitAndPlot()
        tblData = tbl.Data;
        if isempty(tblData)
            uialert(fig, '请先生成表格并输入数据', '无数据');
            return;
        end
        x = tblData(:, 1);
        y = tblData(:, 2);
        % 移除包含 NaN 的行（未输入完整）
        valid = ~isnan(x) & ~isnan(y);
        x = x(valid);
        y = y(valid);
        if length(x) < 2
            uialert(fig, '至少需要两个有效数据点进行线性拟合', '数据不足');
            return;
        end
        
        % 最小二乘法拟合 y = a*x + b
        p = polyfit(x, y, 1);
        a = p(1);
        b = p(2);
        
        % 显示方程
        eqStr = sprintf('y = %.4f x + %.4f', a, b);
        lblResult.Text = eqStr;
        
        % 绘图
        figure('Name', '线性回归结果', 'NumberTitle', 'off');
        plot(x, y, 'ro', 'MarkerSize', 8, 'LineWidth', 1.5); hold on;
        xfit = linspace(min(x), max(x), 100);
        yfit = polyval(p, xfit);
        plot(xfit, yfit, 'b-', 'LineWidth', 2);
        xlabel('x'); ylabel('y');
        title(['拟合直线: ' eqStr]);
        legend('数据点', '拟合直线', 'Location', 'best');
        grid on;
        hold off;
    end
end