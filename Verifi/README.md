### Scoreboard 검증

`spi_scoreboard`는 Monitor가 수집한 Transaction을 받아  
SPI Master와 Slave 사이의 양방향 데이터가 일치하는지 자동으로 검사합니다.

#### 데이터 비교 항목

| 검증 방향 | 예상값(Expected) | 실제값(Actual) | 검증 내용 | Pass 조건 |
|:---:|---|---|---|---|
| Master → Slave | `m_tx_data[7:0]` | `s_rx_data` | AXI4-Lite TX Register에 기록한 Master 송신 데이터가 SPI Slave에 정확히 전달되었는지 확인 | `m_tx_data[7:0] == s_rx_data` |
| Slave → Master | `s_tx_data` | `m_rx_data` | SPI Slave가 MISO로 전송한 데이터가 Master RX Register에 정확히 저장되었는지 확인 | `s_tx_data == m_rx_data` |

#### Scoreboard 동작 과정

| 단계 | 구성 요소 | 동작 |
|:---:|---|---|
| 1 | `spi_driver` | AXI4-Lite 인터페이스를 통해 Master TX 데이터와 Start 신호 인가 |
| 2 | `spi_monitor` | TX Register Write Handshake에서 Master 송신 데이터 수집 |
| 3 | `spi_monitor` | RX Register Read Handshake에서 Master 수신 데이터 수집 |
| 4 | `spi_monitor` | SPI Slave의 송신·수신 데이터를 Transaction에 저장 |
| 5 | `spi_scoreboard` | Master TX와 Slave RX 비교 |
| 6 | `spi_scoreboard` | Slave TX와 Master RX 비교 |
| 7 | `spi_scoreboard` | 두 비교가 모두 일치하면 Pass, 하나라도 다르면 Fail 처리 |

#### 판정 기준

| 판정 | 조건 | UVM 출력 |
|:---:|---|---|
| **PASS** | Master → Slave와 Slave → Master 데이터가 모두 일치 | `UVM_INFO [PASS]` |
| **FAIL** | 두 방향 중 하나 이상의 데이터가 불일치 | `UVM_ERROR [FAIL]` |
| **TIMEOUT** | AXI Handshake 응답이 200 Clock 이내에 발생하지 않음 | `UVM_FATAL [AXI_TIMEOUT]` |

#### 테스트 종료 결과

Simulation 종료 시 `report_phase`에서 전체 Transaction의 결과를 출력합니다.

| 출력 항목 | 설명 |
|---|---|
| `Total` | Scoreboard에서 비교한 전체 Transaction 수 |
| `Pass` | 양방향 데이터가 모두 일치한 Transaction 수 |
| `Fail` | 하나 이상의 데이터가 불일치한 Transaction 수 |
| `Test PASSED` | `Fail == 0`일 때 출력 |
| `Test FAILED` | `Fail > 0`일 때 출력 |

> `spi_rand_sequence`는 총 1,000개의 Random Transaction을 생성합니다.  
> 실제 Pass/Fail 수치는 Simulation 로그를 기준으로 README에 기록합니다.

---

### Coverage 검증

본 검증 환경에서는 **Functional Coverage**와 **Code Coverage**를 함께 사용합니다.

| Coverage 종류 | 목적 | 수집 방법 |
|---|---|---|
| Functional Coverage | 주요 SPI 데이터 패턴이 검증 시나리오에 포함되었는지 확인 | `spi_coverage`의 SystemVerilog Covergroup |
| Code Coverage | DUT의 RTL 코드와 상태가 Simulation에서 실제로 실행되었는지 확인 | Synopsys VCS의 `-cm` 옵션 |
 
#### Functional Coverage

`spi_monitor`가 송수신 결과를 수집할 때마다 Transaction을  
`spi_coverage`로 전달하고, Master와 Slave의 송신 데이터를 샘플링합니다.

##### Master TX Coverage

| Coverpoint | Bin 이름 | 대상 데이터 | 검증 목적 |
|---|---|---|---|
| `cp_m_tx_byte` | `all_zero` | `8'h00` | 모든 비트가 0인 데이터 전송 확인 |
| `cp_m_tx_byte` | `all_one` | `8'hFF` | 모든 비트가 1인 데이터 전송 확인 |
| `cp_m_tx_byte` | `alternating` | `8'h55`, `8'hAA` | 0과 1이 반복되는 패턴에서 비트 밀림 여부 확인 |
| `cp_m_tx_byte` | `walking_ones` | `01, 02, 04, 08, 10, 20, 40, 80` | 단일 1-bit가 각 위치를 통과할 때 전송 오류 확인 |
| `cp_m_tx_byte` | `walking_zeros` | `FE, FD, FB, F7, EF, DF, BF, 7F` | 단일 0-bit가 각 위치를 통과할 때 전송 오류 확인 |
| `cp_m_tx_byte` | `random_others` | 위 패턴을 제외한 데이터 | 일반적인 Random Data 전송 확인 |

##### Slave TX Coverage

| Coverpoint | Bin 이름 | 대상 데이터 | 검증 목적 |
|---|---|---|---|
| `cp_s_tx_data` | `all_zero` | `8'h00` | Slave가 모든 비트가 0인 데이터를 전송하는 경우 확인 |
| `cp_s_tx_data` | `all_one` | `8'hFF` | Slave가 모든 비트가 1인 데이터를 전송하는 경우 확인 |
| `cp_s_tx_data` | `random_others` | `0x00`, `0xFF`를 제외한 데이터 | 다양한 Slave 송신 데이터 검증 |

#### Functional Coverage 결과

Simulation 종료 시 `report_phase`에서 다음 Coverage 결과를 출력합니다.

| 출력 항목 | 설명 |
|---|---|
| `Overall` | 전체 Covergroup의 Functional Coverage |
| `m_tx_byte` | Master TX 데이터 패턴 Coverage |
| `s_tx_data` | Slave TX 데이터 패턴 Coverage |

실제 실행 결과는 다음 표에 기록합니다.

| Coverage 항목 | 측정 결과 | 목표 |
|---|:---:|:---:|
| Overall Functional Coverage | `실행 결과 입력` | 100% |
| Master TX Pattern Coverage | `실행 결과 입력` | 100% |
| Slave TX Pattern Coverage | `실행 결과 입력` | 100% |

> Coverage 수치는 추정값을 작성하지 않고,  
> `make sim` 또는 `make vc` 실행 결과를 확인한 후 입력합니다.

#### Code Coverage

VCS를 통해 다음 RTL Code Coverage 항목을 수집합니다.

| Coverage 항목 | 검증 대상 | 확인 목적 |
|---|---|---|
| Line | RTL 코드의 각 실행문 | 실행되지 않은 코드 확인 |
| Condition | 조건식 내부의 개별 조건 | 조건 조합의 검증 여부 확인 |
| Branch | `if`, `case` 등의 분기 | 모든 제어 경로 실행 여부 확인 |
| FSM | 상태 및 상태 전이 | SPI FSM의 상태·전이 검증 |
| Toggle | 신호의 `0→1`, `1→0` 변화 | 주요 신호의 활성화 여부 확인 |
| Assertion | Assertion 성공·실패 | 프로토콜 조건 위반 여부 확인 |

#### Coverage 확인 방법

| 명령어 | 동작 |
|---|---|
| `make sim` | Simulation 수행 및 Coverage Database 생성 |
| `make vc` | Simulation 후 Verdi Coverage 화면 실행 |
| `make verdi` | Simulation 후 Waveform과 Coverage 분석 환경 실행 |
| `make clean` | Simulation 및 Coverage 생성 파일 삭제 |

```bash
cd Verifi/UVM_AXI_SPI

# 지정된 Seed로 Simulation 및 Coverage 수집
make sim TC=spi_rand_test SEED=1234

# Verdi Coverage 확인
make vc
```

> 현재 Functional Coverage는 송수신 데이터 패턴을 중심으로 구성되어 있습니다.  
> 향후 `CPOL`, `CPHA`, `clk_div`, AXI 응답 지연 및 Timeout 조건을 Coverpoint로  
> 추가하면 SPI Mode와 Bus Timing에 대한 검증 범위를 확장할 수 있습니다.
