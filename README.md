# RunLog — iPhone 운동 기록 앱

GPS를 이용해 이동 거리·평균/최고 속도·km당 랩타임을 기록하는 SwiftUI iPhone 앱입니다. Apple 지도에서 실시간 경로와 운동 이력을 확인하며, 평균 속도에 따라 Health 앱에 걷기 또는 자전거 운동으로 저장합니다.

## 맥북에서 시작하기

### 1. 준비물

- macOS가 설치된 Mac
- **Xcode 15 이상**: App Store에서 설치합니다.
- Apple ID: 실제 iPhone에 설치하려면 필요합니다.
- (권장) iOS 17 이상 iPhone과 USB 케이블

> GPS, 백그라운드 위치 추적, HealthKit은 iOS 시뮬레이터보다 실제 iPhone에서 테스트해야 합니다.

### 2. GitHub에서 프로젝트 받기

Terminal 앱을 열고 원하는 작업 폴더에서 아래 명령을 실행합니다.

```bash
git clone https://github.com/ce90045/RunLog.git
cd RunLog
open RunLog.xcodeproj
```

이미 저장소를 내려받은 경우에는 최신 변경 사항만 받습니다.

```bash
cd RunLog
git pull origin main
open RunLog.xcodeproj
```

### 3. Xcode에서 서명 설정

Xcode가 열리면 왼쪽 탐색기에서 파란색 **RunLog** 프로젝트를 클릭하고, 가운데 목록에서 **RunLog** 타깃을 선택합니다.

1. **Signing & Capabilities** 탭을 엽니다.
2. **Team**에서 본인의 Apple ID 또는 Apple Developer 팀을 선택합니다. Apple ID가 없다면 Xcode 메뉴의 `Xcode > Settings > Accounts`에서 로그인합니다.
3. **Bundle Identifier**를 고유한 값으로 변경합니다. 예: `com.ce90045.runlog`
4. **Automatically manage signing**이 선택되어 있는지 확인합니다.
5. **HealthKit** capability가 목록에 있는지 확인합니다. 없다면 `+ Capability`를 눌러 **HealthKit**을 추가합니다.

무료 Apple ID도 개발용으로 실제 기기에 설치할 수 있습니다. 다만 개발용 서명은 일정 기간 후 갱신이 필요하며, 배포 및 일부 고급 기능에는 Apple Developer Program 가입이 필요할 수 있습니다.

### 4. iPhone 연결 및 실행

1. iPhone을 Mac에 연결하고 잠금을 해제합니다.
2. iPhone에 표시되는 `이 컴퓨터를 신뢰하겠습니까?` 안내에서 **신뢰**를 선택합니다.
3. Xcode 상단 실행 대상 메뉴에서 `RunLog > 내 iPhone 이름`을 선택합니다.
4. `⌘R` 또는 좌측 상단의 재생 버튼을 눌러 빌드와 실행을 시작합니다.

처음 설치 시 iPhone의 `설정 > 일반 > VPN 및 기기 관리`에서 개발자 앱을 신뢰하라는 안내가 나올 수 있습니다. 표시되는 개발자 계정을 신뢰한 뒤 다시 실행하세요.

### 5. 앱 권한 허용

앱을 처음 실행할 때 다음 권한을 허용합니다.

- **위치**: 운동 중 거리와 속도를 계산하고 백그라운드에서 경로를 기록합니다. 가능하면 **항상 허용**을 선택합니다.
- **건강 앱**: 화면 오른쪽 위의 `건강 앱 연결`을 누른 뒤, 운동 데이터 쓰기 권한을 허용합니다.

운동을 종료하면 평균 속도가 **7km/h 이하이면 걷기**, 초과하면 **자전거 운동**으로 Health 앱에 저장됩니다.

### 6. 기능 확인 방법

1. `운동 시작`을 누릅니다.
2. 지도에서 현재 위치와 이동 경로가 표시되는지 확인합니다.
3. 경로 색상은 전체 평균 속도와 비교해 표시됩니다.
   - 파랑: 평균보다 20% 이상 느린 구간
   - 초록: 평균 속도 근처
   - 빨강: 평균보다 20% 이상 빠른 구간
4. 5초 이상 정지하면 자동 홀딩되고, 10m 이상 이동하면 자동으로 재개됩니다.
5. `운동 종료` 후 왼쪽 위 기록 버튼에서 저장된 운동과 지도를 다시 확인합니다.

## Git으로 변경 사항 올리기

Mac에서 코드를 수정한 뒤에는 아래 순서로 GitHub에 반영합니다.

```bash
git status
git add .
git commit -m "설명할 변경 내용"
git push origin main
```

다른 Mac에서 이어서 작업할 때는 먼저 `git pull origin main`을 실행한 뒤 Xcode 프로젝트를 여세요.

## 문제 해결

### `Signing for RunLog requires a development team` 오류

Xcode의 **Signing & Capabilities**에서 Team을 선택하고 Bundle Identifier를 고유한 값으로 바꿉니다.

### 지도에 위치가 보이지 않음

iPhone의 `설정 > 개인정보 보호 및 보안 > 위치 서비스 > 운동 기록`에서 위치 권한을 허용했는지 확인합니다. 실내나 GPS 수신이 약한 곳에서는 위치 갱신이 늦을 수 있습니다.

### Health 앱에 운동이 저장되지 않음

앱에서 `건강 앱 연결`을 다시 누르고 Health 권한을 허용했는지 확인합니다. Xcode 타깃의 HealthKit capability도 확인하세요.
