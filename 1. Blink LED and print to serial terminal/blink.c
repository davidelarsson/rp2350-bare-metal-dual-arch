#include "pico/stdlib.h"
#include <stdio.h>

// Pico 2 has onboard LED on GPIO25
#define LED_PIN 25

int main() {
    stdio_init_all();
    
    // Initialize GPIO25 for the onboard LED
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    printf("Pico 2 Blink Example\n");
    printf("LED blinking at 1Hz on GPIO25...\n");

    // Blink forever
    while (true) {
        printf("LED ON\n");
        gpio_put(LED_PIN, 1);
        sleep_ms(500);
        printf("LED OFF\n");
        gpio_put(LED_PIN, 0);
        sleep_ms(500);
    }
    
    return 0;
}

