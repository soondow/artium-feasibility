function P = paths_local_template()
% 함수 설명:
%   사용자 환경에 맞게 복사해 수정할 수 있는 로컬 경로 템플릿을 생성합니다.
%
% 입력:
%   없음.
%
% 출력:
%   P (구조체: 저장소 루트, 데이터 폴더, 산출물 폴더 경로를 담습니다.)
%
% 예외:
%   필수 필드, 입력 차원, 파일 경로가 맞지 않으면 MATLAB 기본 예외가 발생할 수 있습니다.

    thisFile = mfilename('fullpath');
    configDir = fileparts(thisFile);
    P.repoRoot = fileparts(configDir);

    P.dataRaw = fullfile(P.repoRoot, 'data_external', 'atriaseg_raw');
    P.phase1Root = fullfile(P.repoRoot, 'phase1_anatomy');

    P.outTable = fullfile(P.phase1Root, 'outputs', 'tables');
    P.outPng = fullfile(P.phase1Root, 'outputs', 'preview_png');
end
