/*
 * ap_main.c
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */


#include "ap_main.h"


static hBtn_t hbtnMode;
static hBtn_t hbtnWrite;
static hBtn_t hbtnRead;
sw_t switch_mode;



void ap_init()
{
	//Button_Init(&hbtnMode, GPIOD, GPIO_PIN_5);
    Switch_init(&switch_mode, GPIOA, GPIO_PIN_0 | GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_3 | GPIO_PIN_4| GPIO_PIN_5 | GPIO_PIN_6 | GPIO_PIN_7);
    Button_Init(&hbtnWrite, GPIOD, GPIO_PIN_6);
    Button_Init(&hbtnRead, GPIOD, GPIO_PIN_7);
    SPI_Init(4);
    LED_Init();
    FND_init();

    FND_SetNum(0);

}


void ap_excute()
{ 
    


        if(Button_GetState(&hbtnWrite) == ACT_PUSHED)
        {
            uint8_t sw_state = Switch_ReadExcute(&switch_mode);
            GPIO_WritePin(LED_PORT,0xff, SET);

            SPI_Excute(sw_state);
            GPIO_WritePin(LED_PORT,0xff, RESET);

        }


        if (Button_GetState(&hbtnRead) == ACT_PUSHED) {

               uint8_t rx_data = SPI_Excute(0x00);
               FND_SetNum(rx_data);
           }

           FND_DispDigit();


}

