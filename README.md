# RunApp (Flutter)

Spring Boot 백엔드(Postman 스펙)와 연동되는 러닝 앱 예제입니다.

## 필수 설정

### Google Maps API Key (Android)

`android/local.properties`에 아래를 추가하세요.

```properties
MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY
```

## 실행

```bash
cd runapp
flutter run
```

## 백엔드 연결

기본 Base URL은 `http://localhost:8080`입니다.

- 변경 위치: `lib/src/core/network/api_client.dart`

