/*
 * SPI.c
 *
 *  Created on: 2026. 5. 2.
 *      Author: kccistc
 */
#include "SPI.h"



void SPI_Init(uint8_t clk_div)
{
    SPI->CNTL_REG = (clk_div<<8)| (0<<1) | 0;


}

uint8_t SPI_Excute(uint8_t data)
{   
	SPI->TX_DATA = data;


	    SPI->CNTL_REG |= (1<<31);
	    SPI->CNTL_REG &= ~(1<<31);


	    while(SPI->STATE_REG & (1<<0));

	    return (uint8_t)(SPI->RX_DATA);

//    GPIO_WritePin(GPIOB, GPIO_PIN_1, RESET);
//    GPIO_WritePin(GPIOB, GPIO_PIN_0, SET);
//
//    SPI->CNTL_REG &= ~(1<<31);
//
//    delay_ms(10);



}

uint8_t SPI_Receive()
{   
    return (uint8_t)(SPI->RX_DATA);

}


