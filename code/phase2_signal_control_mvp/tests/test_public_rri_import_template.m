% 테스트 설명:
%   공개 RRI CSV 가져오기 템플릿이 기본 스키마를 읽고 윈도우로 분할되는지 검증합니다.
%
% 입력:
%   테스트 안에서 생성한 임시 RRI CSV 파일을 사용합니다.
%
% 출력:
%   assert 기반 검증 결과를 테스트 러너에 전달합니다.
%
% 예외:
%   CSV 가져오기, 시나리오명 보존, 시간 정렬, 윈도우 분할 조건을 만족하지 않으면 assert 예외가 발생합니다.


phase2Root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(phase2Root, 'functions'));

tmpPath = fullfile(tempdir, 'phase2_public_rri_import_smoke.csv');
t = (0:119)';
rri = 800 + 20 * sin(2 * pi * t / 30);
T = table(t, rri, 'VariableNames', {'time_sec', 'rri_ms'});
writetable(T, tmpPath);

S = import_public_rri_csv(tmpPath, 'ScenarioName', "public_smoke_test");
assert(S.scenario == "public_smoke_test", 'Scenario name was not preserved.');
assert(numel(S.rri_ms) == height(T), 'Imported RRI length mismatch.');
assert(all(S.rri_ms > 0), 'Imported RRI values must be positive.');
assert(all(diff(S.time_sec) >= 0), 'Imported time_sec must be monotonic.');

W = segment_rri_windows(S, 60, 30);
assert(height(W) >= 2, 'Imported public RRI stream should segment into windows.');
