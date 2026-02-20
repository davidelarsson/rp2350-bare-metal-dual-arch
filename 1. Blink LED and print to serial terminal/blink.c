#include "pico/stdlib.h"
#include "pico/cyw43_arch.h"
#include <stdio.h>

int main() {
    stdio_init_all();
    
    // Initialize the CYW43 wireless chip (controls the LED on Pico W)
    if (cyw43_arch_init()) {
        printf("Failed to initialize CYW43\n");
        return -1;
    }

    printf("Pico 2W Blink Example\n");
    printf("LED blinking at 1Hz...\n");

    // Blink forever
    while (true) {
        printf("LED ON\n");
        cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
        sleep_ms(500);
        printf("LED OFF\n");
        cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);
        sleep_ms(500);
    }
    
    cyw43_arch_deinit();
    return 0;
}
