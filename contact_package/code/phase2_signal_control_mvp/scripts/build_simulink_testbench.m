% 스크립트 설명:
%   Phase 2 관찰자-제어기 정책을 수치 step 입력으로 검증하는 Simulink 테스트벤치를 생성합니다.
%
% 입력:
%   프로젝트 설정 경로, 내부 함수, 스크립트 안에서 정의한 파라미터를 사용합니다.
%
% 출력:
%   콘솔 로그, CSV 테이블, 그림, 또는 Simulink 산출물을 생성할 수 있습니다.
%
% 예외:
%   파일 경로, 내부 함수 입력 조건, 저장 과정에서 발생한 MATLAB 예외가 전파될 수 있습니다.


clear; clc;

thisFile = mfilename('fullpath');
scriptDir = fileparts(thisFile);
phase2Root = fileparts(scriptDir);
outDir = fullfile(phase2Root, 'outputs', 'simulink');
figDir = fullfile(phase2Root, 'figures');

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

if ~exist(figDir, 'dir')
    mkdir(figDir);
end

if ~(exist('new_system', 'file') == 2 || exist('new_system', 'builtin') == 5)
    warning('Simulink is not available on this MATLAB path. Testbench model was not created.');
    return;
end

modelName = 'phase2_signal_control_testbench';
modelPath = fullfile(outDir, [modelName '.slx']);

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

if isfile(modelPath)
    delete(modelPath);
end

new_system(modelName);
open_system(modelName);
set_param(modelName, 'StopTime', '80');
set_param(modelName, 'Solver', 'FixedStepDiscrete');
set_param(modelName, 'FixedStep', '1');

add_block('simulink/Sources/Constant', [modelName '/base_risk_0p15'], ...
    'Value', '0.15', 'Position', [40 65 105 95]);
add_block('simulink/Sources/Step', [modelName '/artifact_risk_step_up'], ...
    'Time', '20', 'Before', '0', 'After', '0.78', 'Position', [40 115 105 145]);
add_block('simulink/Sources/Step', [modelName '/artifact_risk_step_down'], ...
    'Time', '55', 'Before', '0', 'After', '-0.78', 'Position', [40 165 105 195]);
add_block('simulink/Math Operations/Sum', [modelName '/Feature Extraction - risk proxy'], ...
    'Inputs', '+++', 'Position', [165 105 205 165]);

add_block('simulink/Sources/Constant', [modelName '/base_quality_0p95'], ...
    'Value', '0.95', 'Position', [40 290 105 320]);
add_block('simulink/Sources/Step', [modelName '/quality_drop_step'], ...
    'Time', '20', 'Before', '0', 'After', '-0.42', 'Position', [40 340 105 370]);
add_block('simulink/Sources/Step', [modelName '/quality_recovery_step'], ...
    'Time', '55', 'Before', '0', 'After', '0.42', 'Position', [40 390 105 420]);
add_block('simulink/Math Operations/Sum', [modelName '/SQI Estimator - q raw'], ...
    'Inputs', '+++', 'Position', [165 330 205 390]);
add_block('simulink/Discontinuities/Saturation', [modelName '/SQI Estimator - q_k'], ...
    'UpperLimit', '1', 'LowerLimit', '0', 'Position', [245 342 315 378]);

add_block('simulink/Sources/Constant', [modelName '/one'], ...
    'Value', '1', 'Position', [355 295 400 325]);
add_block('simulink/Math Operations/Sum', [modelName '/one_minus_q'], ...
    'Inputs', '+-', 'Position', [455 325 495 375]);

add_block('simulink/Math Operations/Product', [modelName '/q_times_risk'], ...
    'Position', [375 105 425 155]);
add_block('simulink/Math Operations/Product', [modelName '/one_minus_q_times_x_prev'], ...
    'Position', [555 210 605 260]);
add_block('simulink/Math Operations/Sum', [modelName '/Risk-State Observer - x update'], ...
    'Inputs', '++', 'Position', [665 155 705 215]);
add_block('simulink/Discontinuities/Saturation', [modelName '/Risk-State Observer - x_hat'], ...
    'UpperLimit', '1', 'LowerLimit', '0', 'Position', [745 165 815 205]);
add_block('simulink/Discrete/Unit Delay', [modelName '/observer_state_memory'], ...
    'InitialCondition', '0.15', 'SampleTime', '1', 'Position', [745 245 815 285]);

add_block('simulink/Math Operations/Gain', [modelName '/uncertainty_gain_1p2'], ...
    'Gain', '1.2', 'Position', [555 330 615 370]);
add_block('simulink/Discontinuities/Saturation', [modelName '/Risk-State Observer - U_k'], ...
    'UpperLimit', '1', 'LowerLimit', '0', 'Position', [665 332 735 368]);

add_block('simulink/Sources/Constant', [modelName '/threshold_base_0p52'], ...
    'Value', '0.52', 'Position', [860 110 925 140]);
add_block('simulink/Math Operations/Gain', [modelName '/U_threshold_gain_0p28'], ...
    'Gain', '0.28', 'Position', [860 185 925 215]);
add_block('simulink/Math Operations/Gain', [modelName '/low_quality_gain_0p18'], ...
    'Gain', '0.18', 'Position', [860 335 925 365]);
add_block('simulink/Math Operations/Sum', [modelName '/Adaptive Threshold Controller - theta_k'], ...
    'Inputs', '+++', 'Position', [985 190 1025 250]);

add_block('simulink/Logic and Bit Operations/Relational Operator', [modelName '/x_hat_ge_theta'], ...
    'Operator', '>=', 'Position', [1085 155 1145 195]);
add_block('simulink/Sources/Constant', [modelName '/quality_gate_0p82'], ...
    'Value', '0.82', 'Position', [985 305 1050 335]);
add_block('simulink/Logic and Bit Operations/Relational Operator', [modelName '/q_ge_quality_gate'], ...
    'Operator', '>=', 'Position', [1085 270 1145 310]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [modelName '/direct_alert_AND_quality_gate'], ...
    'Operator', 'AND', 'Inputs', '2', 'Position', [1210 200 1265 250]);

add_block('simulink/Sources/Constant', [modelName '/fixed_risk_gate_0p62'], ...
    'Value', '0.62', 'Position', [985 45 1050 75]);
add_block('simulink/Logic and Bit Operations/Relational Operator', [modelName '/raw_risk_ge_fixed_gate'], ...
    'Operator', '>=', 'Position', [1085 45 1145 85]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [modelName '/not_reliable_quality'], ...
    'Operator', 'NOT', 'Position', [1210 290 1265 330]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [modelName '/request_confirmation_AND_unreliable'], ...
    'Operator', 'AND', 'Inputs', '2', 'Position', [1325 105 1380 155]);

add_block('simulink/Signal Attributes/Data Type Conversion', [modelName '/direct_alert_to_double'], ...
    'OutDataTypeStr', 'double', 'Position', [1325 218 1390 252]);
add_block('simulink/Signal Attributes/Data Type Conversion', [modelName '/request_confirmation_to_double'], ...
    'OutDataTypeStr', 'double', 'Position', [1410 105 1475 140]);

add_block('simulink/Signal Routing/Mux', [modelName '/Alert Policy Logger - mux'], ...
    'Inputs', '7', 'Position', [1530 120 1570 340]);
add_block('simulink/Sinks/To Workspace', [modelName '/Alert Policy Logger - To Workspace'], ...
    'VariableName', 'phase2_closed_loop_log', 'SaveFormat', 'Timeseries', ...
    'Position', [1630 210 1745 250]);

addLines(modelName);

annotation = Simulink.Annotation(modelName, ...
    ['Numeric step-function monitoring-policy testbench', newline, ...
    'Artifact-like risk step with low q_k routes to request/confirmation instead of direct alert.']);
annotation.Position = [455 30 930 75];

try
    Simulink.BlockDiagram.arrangeSystem(modelName);
    print(['-s' modelName], '-dpng', fullfile(figDir, 'simulink_block_diagram.png'));
catch ME
    warning('Could not export Simulink block diagram PNG: %s', ME.message);
end

save_system(modelName, modelPath);

simOut = sim(modelName, 'StopTime', '80');
ts = simOut.phase2_closed_loop_log;
logData = ts.Data;
if ndims(logData) == 3
    logData = squeeze(logData);
end

timeSec = ts.Time;
riskProxy = logData(:, 1);
q = logData(:, 2);
coverage = ones(size(q));
xHat = logData(:, 3);
U = logData(:, 4);
tau = logData(:, 5);
directAlert = logData(:, 6);
requestMoreData = zeros(size(directAlert));
requestConfirmation = logData(:, 7);
policyCode = 3 * directAlert + requestMoreData + 2 * requestConfirmation;
k = (0:numel(timeSec) - 1)';

simTable = table(k, timeSec, riskProxy, q, coverage, xHat, U, tau, ...
    directAlert, requestMoreData, requestConfirmation, policyCode, ...
    'VariableNames', {'k', 'time_sec', 'risk_proxy', 'q', 'coverage', ...
    'x_hat', 'U', 'tau', 'direct_alert', 'request_more_data', ...
    'request_confirmation', 'policy_code'});
writetable(simTable, fullfile(outDir, 'simulink_step_testbench_log.csv'));

plotSimulinkTestbench(simTable, figDir);

close_system(modelName, 0);

fprintf('Saved numeric Simulink testbench: %s\n', modelPath);
fprintf('Saved Simulink log: %s\n', fullfile(outDir, 'simulink_step_testbench_log.csv'));

function addLines(modelName)
% 함수 설명:
%   Simulink 테스트벤치 모델에 주요 신호 연결선을 추가합니다.
%
% 입력:
%   modelName (문자열, 비어 있을 수 없음: Simulink 모델 이름입니다.)
%
% 출력:
%   없음.
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    add_line(modelName, 'base_risk_0p15/1', 'Feature Extraction - risk proxy/1', 'autorouting', 'on');
    add_line(modelName, 'artifact_risk_step_up/1', 'Feature Extraction - risk proxy/2', 'autorouting', 'on');
    add_line(modelName, 'artifact_risk_step_down/1', 'Feature Extraction - risk proxy/3', 'autorouting', 'on');

    add_line(modelName, 'base_quality_0p95/1', 'SQI Estimator - q raw/1', 'autorouting', 'on');
    add_line(modelName, 'quality_drop_step/1', 'SQI Estimator - q raw/2', 'autorouting', 'on');
    add_line(modelName, 'quality_recovery_step/1', 'SQI Estimator - q raw/3', 'autorouting', 'on');
    add_line(modelName, 'SQI Estimator - q raw/1', 'SQI Estimator - q_k/1', 'autorouting', 'on');

    add_line(modelName, 'Feature Extraction - risk proxy/1', 'q_times_risk/1', 'autorouting', 'on');
    add_line(modelName, 'SQI Estimator - q_k/1', 'q_times_risk/2', 'autorouting', 'on');

    add_line(modelName, 'one/1', 'one_minus_q/1', 'autorouting', 'on');
    add_line(modelName, 'SQI Estimator - q_k/1', 'one_minus_q/2', 'autorouting', 'on');
    add_line(modelName, 'one_minus_q/1', 'one_minus_q_times_x_prev/1', 'autorouting', 'on');
    add_line(modelName, 'observer_state_memory/1', 'one_minus_q_times_x_prev/2', 'autorouting', 'on');

    add_line(modelName, 'q_times_risk/1', 'Risk-State Observer - x update/1', 'autorouting', 'on');
    add_line(modelName, 'one_minus_q_times_x_prev/1', 'Risk-State Observer - x update/2', 'autorouting', 'on');
    add_line(modelName, 'Risk-State Observer - x update/1', 'Risk-State Observer - x_hat/1', 'autorouting', 'on');
    add_line(modelName, 'Risk-State Observer - x_hat/1', 'observer_state_memory/1', 'autorouting', 'on');

    add_line(modelName, 'one_minus_q/1', 'uncertainty_gain_1p2/1', 'autorouting', 'on');
    add_line(modelName, 'uncertainty_gain_1p2/1', 'Risk-State Observer - U_k/1', 'autorouting', 'on');

    add_line(modelName, 'threshold_base_0p52/1', 'Adaptive Threshold Controller - theta_k/1', 'autorouting', 'on');
    add_line(modelName, 'Risk-State Observer - U_k/1', 'U_threshold_gain_0p28/1', 'autorouting', 'on');
    add_line(modelName, 'U_threshold_gain_0p28/1', 'Adaptive Threshold Controller - theta_k/2', 'autorouting', 'on');
    add_line(modelName, 'one_minus_q/1', 'low_quality_gain_0p18/1', 'autorouting', 'on');
    add_line(modelName, 'low_quality_gain_0p18/1', 'Adaptive Threshold Controller - theta_k/3', 'autorouting', 'on');

    add_line(modelName, 'Risk-State Observer - x_hat/1', 'x_hat_ge_theta/1', 'autorouting', 'on');
    add_line(modelName, 'Adaptive Threshold Controller - theta_k/1', 'x_hat_ge_theta/2', 'autorouting', 'on');
    add_line(modelName, 'SQI Estimator - q_k/1', 'q_ge_quality_gate/1', 'autorouting', 'on');
    add_line(modelName, 'quality_gate_0p82/1', 'q_ge_quality_gate/2', 'autorouting', 'on');
    add_line(modelName, 'x_hat_ge_theta/1', 'direct_alert_AND_quality_gate/1', 'autorouting', 'on');
    add_line(modelName, 'q_ge_quality_gate/1', 'direct_alert_AND_quality_gate/2', 'autorouting', 'on');

    add_line(modelName, 'Feature Extraction - risk proxy/1', 'raw_risk_ge_fixed_gate/1', 'autorouting', 'on');
    add_line(modelName, 'fixed_risk_gate_0p62/1', 'raw_risk_ge_fixed_gate/2', 'autorouting', 'on');
    add_line(modelName, 'q_ge_quality_gate/1', 'not_reliable_quality/1', 'autorouting', 'on');
    add_line(modelName, 'raw_risk_ge_fixed_gate/1', 'request_confirmation_AND_unreliable/1', 'autorouting', 'on');
    add_line(modelName, 'not_reliable_quality/1', 'request_confirmation_AND_unreliable/2', 'autorouting', 'on');

    add_line(modelName, 'Feature Extraction - risk proxy/1', 'Alert Policy Logger - mux/1', 'autorouting', 'on');
    add_line(modelName, 'SQI Estimator - q_k/1', 'Alert Policy Logger - mux/2', 'autorouting', 'on');
    add_line(modelName, 'Risk-State Observer - x_hat/1', 'Alert Policy Logger - mux/3', 'autorouting', 'on');
    add_line(modelName, 'Risk-State Observer - U_k/1', 'Alert Policy Logger - mux/4', 'autorouting', 'on');
    add_line(modelName, 'Adaptive Threshold Controller - theta_k/1', 'Alert Policy Logger - mux/5', 'autorouting', 'on');
    add_line(modelName, 'direct_alert_AND_quality_gate/1', 'direct_alert_to_double/1', 'autorouting', 'on');
    add_line(modelName, 'request_confirmation_AND_unreliable/1', 'request_confirmation_to_double/1', 'autorouting', 'on');
    add_line(modelName, 'direct_alert_to_double/1', 'Alert Policy Logger - mux/6', 'autorouting', 'on');
    add_line(modelName, 'request_confirmation_to_double/1', 'Alert Policy Logger - mux/7', 'autorouting', 'on');
    add_line(modelName, 'Alert Policy Logger - mux/1', 'Alert Policy Logger - To Workspace/1', 'autorouting', 'on');
end

function plotSimulinkTestbench(simTable, figDir)
% 함수 설명:
%   Simulink step 테스트벤치 실행 결과를 요약 그림으로 저장합니다.
%
% 입력:
%   simTable (테이블, 비어 있을 수 없음: Simulink 테스트벤치 실행 로그입니다.)
%   figDir (문자열, 비어 있을 수 없음: 그림 산출물을 저장할 폴더 경로입니다.)
%
% 출력:
%   없음.
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.
    f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 760]);
    tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'Simulink numeric step-function monitoring-policy testbench', 'FontWeight', 'bold');

    nexttile;
    plot(simTable.time_sec, simTable.risk_proxy, 'Color', [0.65 0.18 0.18], 'LineWidth', 1.3); hold on;
    plot(simTable.time_sec, simTable.x_hat, 'Color', [0.10 0.32 0.70], 'LineWidth', 1.3);
    plot(simTable.time_sec, simTable.tau, '--', 'Color', [0.48 0.23 0.72], 'LineWidth', 1.2);
    ylabel('risk/state');
    legend({'risk proxy', 'x\_hat', 'theta\_k'}, 'Location', 'northwest');
    grid on;

    nexttile;
    plot(simTable.time_sec, simTable.q, 'Color', [0.00 0.45 0.30], 'LineWidth', 1.3); hold on;
    plot(simTable.time_sec, simTable.U, 'Color', [0.48 0.23 0.72], 'LineWidth', 1.2);
    ylabel('q / U');
    ylim([0 1.05]);
    legend({'q\_k', 'U\_k'}, 'Location', 'southwest');
    grid on;

    nexttile;
    stairs(simTable.time_sec, simTable.direct_alert, 'Color', [0.10 0.32 0.70], 'LineWidth', 1.4); hold on;
    stairs(simTable.time_sec, 0.6 * simTable.request_confirmation, 'Color', [0.85 0.55 0.10], 'LineWidth', 1.4);
    xlabel('time (sec)');
    ylabel('policy');
    ylim([-0.05 1.1]);
    yticks([0 0.6 1]);
    yticklabels({'none', 'confirm', 'alert'});
    grid on;

    exportgraphics(f, fullfile(figDir, 'figure_05_simulink_step_testbench.png'), 'Resolution', 180);
    close(f);
end
