% 테스트 설명:
%   신호 품질 계산 결과가 0 이상 1 이하 범위를 유지하고 인공물 구간을 낮은 품질로 평가하는지 검증합니다.
%
% 입력:
%   테스트 내부에서 정의한 합성 데이터, 프로젝트 함수, 또는 기존 산출물을 사용합니다.
%
% 출력:
%   조건을 만족하면 조용히 종료하고, 실패하면 assert 또는 error 예외가 발생합니다.
%
% 예외:
%   파일 경로, 내부 함수 입력 조건, 저장 과정에서 발생한 MATLAB 예외가 전파될 수 있습니다.


T = readtable(fullfile(phase2Root, 'outputs', 'tables', 'window_metrics.csv'));

assert(all(T.q >= 0 & T.q <= 1), 'q_k must be bounded in [0, 1]');
assert(all(T.coverage >= 0 & T.coverage <= 1), 'coverage c_k must be bounded in [0, 1]');

lowq = T(string(T.scenario) == "low_quality_artifact", :);
lowqMask = logical(lowq.true_low_quality);
assert(mean(lowq.q(lowqMask), 'omitnan') < mean(lowq.q(~lowqMask), 'omitnan'), ...
    'Artifact segment should reduce signal quality.');

missing = T(string(T.scenario) == "missing_burst", :);
missingMask = logical(missing.true_low_quality);
assert(mean(missing.coverage(missingMask), 'omitnan') ...
    < mean(missing.coverage(~missingMask), 'omitnan'), ...
    'Missing burst should reduce coverage.');
