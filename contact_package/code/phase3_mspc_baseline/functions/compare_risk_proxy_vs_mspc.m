function T = compare_risk_proxy_vs_mspc(windowMetrics, mspcRisk)
% 함수 설명:
%   기존 HRV 위험 프록시와 MSPC 기반 위험 관측값을 같은 윈도우 단위로 비교합니다.
%
% 입력:
%   windowMetrics (테이블, 비어 있을 수 없음: Phase 2 윈도우 특징, 품질, 라벨 컬럼을 포함한 테이블입니다.)
%   mspcRisk (수치형 벡터, 비어 있을 수 없음: MSPC 점수를 변환한 위험 관측값입니다.)
%
% 출력:
%   T (테이블: 함수 목적에 따른 비교 결과, 전처리 결과, 또는 윈도우별 파이프라인 결과를 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.

    riskProxy = windowMetrics.risk_proxy;
    hybridRisk = max(riskProxy, mspcRisk);

    T = table(windowMetrics.scenario, windowMetrics.window_id, windowMetrics.day0_6, ...
        riskProxy, mspcRisk, hybridRisk, windowMetrics.q, windowMetrics.coverage, ...
        windowMetrics.true_risk, windowMetrics.true_low_quality, ...
        'VariableNames', {'scenario', 'window_id', 'day0_6', ...
        'risk_proxy', 'mspc_risk', 'hybrid_risk', 'q', 'coverage', ...
        'true_risk', 'true_low_quality'});
end
