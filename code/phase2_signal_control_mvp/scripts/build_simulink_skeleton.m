% 스크립트 설명:
%   Phase 2 신호 제어 개념을 설명하는 Simulink 골격 모델을 생성합니다.
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
run(fullfile(scriptDir, 'build_simulink_testbench.m'));
