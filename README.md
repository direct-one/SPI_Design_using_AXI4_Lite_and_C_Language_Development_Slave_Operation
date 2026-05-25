# AXI4_Lite_SPI

# 🛰️ AXI4-Lite SPI Master Control System

본 프로젝트는 FPGA 환경에서 **AXI4-Lite 버스**를 통해 제어되는 SPI Master IP를 활용하여, 하드웨어 스위치 및 버튼 입력을 처리하고 외부 SPI 슬레이브 장치와 데이터를 주고받는 시스템입니다.

## 📌 핵심 기능

- **SPI Data Transmission**: DIP 스위치(`GPIOA`)로 입력된 8비트 데이터를 버튼(`GPIOD Pin 6`) 클릭 시 SPI 슬레이브로 전송합니다.
- **SPI Data Reception**: 읽기 버튼(`GPIOD Pin 7`) 클릭 시 슬레이브로부터 데이터를 수신하여 FND(7-Segment)에 출력합니다.
- **Visual Feedback**: 데이터 전송 시 LED가 점등되어 동작 상태를 즉각적으로 확인할 수 있습니다.
- **Modular Initialization**: SPI 통신 속도(Prescaler) 및 주변 장치(LED, FND, Switch)를 구조적으로 초기화합니다.

## 🛠️ 하드웨어 구성 (Peripheral Mapping)

| **장치** | **포트 (GPIO)** | **역할** |
| --- | --- | --- |
| **DIP Switch** | `GPIOA [0:7]` | 전송할 8-bit 데이터 설정 |
| **Write Button** | `GPIOD Pin 6` | SPI 데이터 전송(Write) 트리거 |
| **Read Button** | `GPIOD Pin 7` | SPI 데이터 수신(Read) 트리거 |
| **LED** | `LED_PORT` | 데이터 전송 중 상태 표시 |
| **FND** | `FND_PORT` | 수신된 8-bit 데이터를 10진수로 표시 |
| **SPI Master** | `Internal IP` | AXI4-Lite를 통해 슬레이브와 통신 |

## 🗺️ AXI-SPI Register Mapping

| 레지스터 (Register) | 오프셋 (Offset) | 권한 (Access) | 필드 (Fields) & 상세 설명 (Description) |
| :--- | :---: | :---: | :--- |
| **`slv_reg0`**<br>(Control) | `0x00` | R/W | <ul><li>`cpol`, `cpha`: SPI 모드 선택 (Mode_Select)</li><li>`clk_div`: 클럭 분주비 설정</li><li>`start`: 전송 시작 트리거 (버튼 `btn_r` 연결)</li></ul> |
| **`slv_reg1`**<br>(TX Data) | `0x04` | W | <ul><li>`tx_data`: 전송할 송신 데이터 (Transmit Data)</li></ul> |
| **`slv_reg2`**<br>(Status) | `0x08` | R | <ul><li>`done`: 전송 완료 상태 플래그</li><li>`busy`: SPI 통신 진행 중 상태 플래그 (State_Condition)</li></ul> |
| **`slv_reg3`**<br>(RX Data) | `0x0C` | R | <ul><li>`rx_data`: 수신된 데이터 (Receive Data)</li></ul> |

## 📂 소프트웨어 로직 흐름

### 1. 초기화 (`ap_init`)

- 사용자 입력 장치(Switch, Button)의 핀 맵 설정.
- `SPI_Init(4)`: SPI 모듈의 분주비를 설정하여 통신 속도 결정.
- FND 초기값을 0으로 설정하여 대기 상태 진입.

### 2. 메인 루프 (`ap_excute`)

- **Write 동작**:
    1. `hbtnWrite`가 눌리면 `Switch_ReadExcute()`를 통해 현재 스위치 값을 읽음.
    2. LED를 켜서 동작 중임을 알림.
    3. `SPI_Excute(sw_state)`를 호출하여 슬레이브로 데이터 전송.
- **Read 동작**:
    1. `hbtnRead`가 눌리면 `0x00` 더미 데이터를 보내며 슬레이브의 데이터를 수신.
    2. 수신된 `rx_data`를 `FND_SetNum()`을 통해 세그먼트에 표시.
- **Display**: `FND_DispDigit()`를 지속적으로 호출하여 잔상 효과를 통한 수치 출력 유지.

## 💻 코드 하이라이트 (SPI 제어)

C

```c
// 데이터 전송 및 수신 프로세스
if(Button_GetState(&hbtnWrite) == ACT_PUSHED) {
    uint8_t sw_state = Switch_ReadExcute(&switch_mode);
    GPIO_WritePin(LED_PORT, 0xff, SET); // 전송 시작 알림
    SPI_Excute(sw_state);               // AXI4-Lite 기반 SPI 전송
    GPIO_WritePin(LED_PORT, 0xff, RESET);
}

if (Button_GetState(&hbtnRead) == ACT_PUSHED) {
    uint8_t rx_data = SPI_Excute(0x00); // 데이터 읽기
    FND_SetNum(rx_data);                // 수신 데이터 표시
}
```

