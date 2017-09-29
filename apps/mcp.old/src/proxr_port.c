/*
 *  Copyright 2014 Frank Hunleth
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * PROXR port implementation.
 *
 * This code has been heavily modified from Erlang/ALE.
 * Copyright (C) 2013 Erlang Solutions Ltd.
 * See http://opensource.erlang-solutions.com/erlang_ale/.
 */

#include <err.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <sys/param.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <ctype.h>
#include <unistd.h>

#include "erlcmd.h"

//#define DEBUG
#ifdef DEBUG
#define debug(...) do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\r\n"); } while(0)
#else
#define debug(...)
#endif

#define PROXR_BUFFER_MAX 32

struct proxr_info
{
    int fd;
};

void set_raw_tty_mode(int fd) {
  struct termios ttymodes;

  /* Get ttymodes */
  if (tcgetattr(fd,&ttymodes) < 0) err(EXIT_FAILURE, "tcgetattr");

  /* Configure for raw mode (see man termios) */
  ttymodes.c_cc[VMIN] = 0;        	/* VMIN=0 and TIME=0 is a polling read */
  ttymodes.c_cc[VTIME] = 0;        /* do not wait to fill buffer */

  ttymodes.c_iflag &= ~(ICRNL |    /* disable CR-to-NL mapping */
			INLCR |    /* disable NL-to-CR mapping */
			IGNCR |    /* disable ignore CR */
			ISTRIP |   /* disable stripping of eighth bit */
			IXON |     /* disable output flow control */
			BRKINT |   /* disable generate SIGINT on brk */
			IGNPAR |
			PARMRK |
			IGNBRK |
			INPCK);    /* disable input parity detection */

  ttymodes.c_lflag &= ~(ICANON |   /* enable non-canonical mode */
			ECHO |     /* disable character echo */
			ECHOE |    /* disable visual erase */
			ECHOK |    /* disable echo newline after kill */
			ECHOKE |   /* disable visual kill with bs-sp-bs */
			ECHONL |   /* disable echo nl when echo off */
			ISIG | 	   /* disable tty-generated signals */
			IEXTEN);   /* disable extended input processing */

  ttymodes.c_cflag |= CS8;         /* enable eight bit chars */
  ttymodes.c_cflag &= ~PARENB;     /* disable input parity check */
  ttymodes.c_oflag &= ~OPOST;      /* disable output processing */
  ttymodes.c_cflag |= CLOCAL;

  /* the proxr only supports 115,200 baud and no flow control...
    hard code it here */
  cfsetispeed(&ttymodes, B115200);
  cfsetospeed(&ttymodes, B115200);
  ttymodes.c_cflag &= ~CRTSCTS;

  /* Apply changes and flush */
  if (tcsetattr(fd, TCSAFLUSH, &ttymodes) < 0) err(EXIT_FAILURE, "tcsetattr");
}

static void proxr_init(struct proxr_info *proxr, const char *devpath)
{
    // Fail hard on error. May need to be nicer if this makes the
    // Erlang side too hard to debug.
    proxr->fd = open(devpath, O_RDWR);
    if (proxr->fd < 0) err(EXIT_FAILURE, "open %s", devpath);

    set_raw_tty_mode(proxr->fd);
}

/**
 * @brief	PROXR combined write/read operation
 *
 * @return 	1 for success, 0 for failure
 */
static int proxr_transfer(const struct proxr_info *proxr,
                        const uint8_t *to_write, size_t to_write_len,
                        uint8_t *to_read, size_t to_read_len)
{
    int rc = 1;
    struct termios ttymodes;

    if (tcgetattr(proxr->fd,&ttymodes) < 0) err(EXIT_FAILURE, "tcgetattr");
    ttymodes.c_cc[VMIN] = to_read_len;
    ttymodes.c_cc[VTIME] = 0;
    if (tcsetattr(proxr->fd, TCSAFLUSH, &ttymodes) < 0) err(EXIT_FAILURE, "tcsetattr");

    rc = write(proxr->fd, to_write, to_write_len);

    if (rc >= 0) {
      if ((size_t)read(proxr->fd, to_read, to_read_len) != to_read_len) rc = -1;
    }

    if (rc < 0)
        return 0;
    else
        return 1;
}

static void proxr_handle_request(const char *req, void *cookie)
{
    struct proxr_info *proxr = (struct proxr_info *) cookie;

    // Commands are of the form {Command, Arguments}:
    // { atom(), term() }
    int req_index = sizeof(uint16_t);
    if (ei_decode_version(req, &req_index, NULL) < 0)
        errx(EXIT_FAILURE, "Message version issue?");

    int arity;
    if (ei_decode_tuple_header(req, &req_index, &arity) < 0 ||
            arity != 2)
        errx(EXIT_FAILURE, "expecting {cmd, args} tuple");

    char cmd[MAXATOMLEN];
    if (ei_decode_atom(req, &req_index, cmd) < 0)
        errx(EXIT_FAILURE, "expecting command atom");

    unsigned int args;
    if (ei_decode_long(req, &req_index, (long int *) &args) < 0 ||
            args > 255)
        errx(EXIT_FAILURE, "args: min=0, max=255");

    char resp[1024]; // Allow up to 1k in the port response
    int resp_index = sizeof(uint16_t); // Space for payload size
    ei_encode_version(resp, &resp_index);
    if (strcmp(cmd, "ping") == 0) {
        uint8_t ping_cmd[3] = {254, 33, 0};
        uint8_t data[PROXR_BUFFER_MAX];

        if (proxr_transfer(proxr, ping_cmd, 2, data, 1)) {
          if (data[0] == 85) ei_encode_atom(resp, &resp_index, "pong");
		}
        else {
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "error");
            ei_encode_atom(resp, &resp_index, "proxr_ping_failed");
        }
    } else if (strcmp(cmd, "read_relays") == 0) {
        uint8_t read_relays_cmd[4] = { 254, 124, 1, 0};
        uint8_t data[PROXR_BUFFER_MAX];

        if (proxr_transfer(proxr, read_relays_cmd, 3, data, 1)) {
          ei_encode_tuple_header(resp, &resp_index, 2);
          ei_encode_atom(resp, &resp_index, "relay_positions");
          ei_encode_char(resp, &resp_index, data[0]);
        }
        else {
          ei_encode_tuple_header(resp, &resp_index, 2);
          ei_encode_atom(resp, &resp_index, "error");
          ei_encode_atom(resp, &resp_index, "proxr_read_relays_failed");
        }
    } else if (strcmp(cmd, "read_analog") == 0) {
        uint8_t read_analog_cmd[3] = {254, 167, 0};
        uint8_t data[PROXR_BUFFER_MAX];
				uint8_t i = 0;

        if (proxr_transfer(proxr, read_analog_cmd, 2, data, 16)) {
          ei_encode_tuple_header(resp, &resp_index, 2);
          ei_encode_atom(resp, &resp_index, "analog_readings");
          for(i=0; i<8; i++) {
            ei_encode_list_header(resp, &resp_index, 1);
            unsigned long raw = data[i*2]*256 + data[(i*2)+1];
            unsigned long millivolts = (raw/1023.0)*5.0 * 1000;
            ei_encode_ulong(resp, &resp_index, millivolts);
          }
          ei_encode_empty_list(resp, &resp_index);
        }
        else {
          ei_encode_tuple_header(resp, &resp_index, 2);
          ei_encode_atom(resp, &resp_index, "error");
          ei_encode_atom(resp, &resp_index, "proxr_read_analog_failed");
        }
    } else if (strcmp(cmd, "set_relays") == 0) {
        /* note: third byte is the char value of relay positions */
        uint8_t set_relays_cmd[5] = {254, 140, 0, 1, 0};
        uint8_t data[PROXR_BUFFER_MAX];

        set_relays_cmd[2] = args;

        if (proxr_transfer(proxr, set_relays_cmd, 4, data, 1) &&
          (data[0] == 85)) {
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "ok");
            ei_encode_atom(resp, &resp_index, "proxr_set_relays_success");
        }
        else {
          ei_encode_tuple_header(resp, &resp_index, 2);
          ei_encode_atom(resp, &resp_index, "error");
          ei_encode_atom(resp, &resp_index, "proxr_set_relays_failed");
        }
    } else if (strcmp(cmd, "all_off") == 0) {
        uint8_t all_off_cmd[4] = {254, 129, 1, 0};
        uint8_t data[PROXR_BUFFER_MAX];

        if (proxr_transfer(proxr, all_off_cmd, 3, data, 1) &&
          (data[0] == 85)) {
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "ok");
            ei_encode_atom(resp, &resp_index, "proxr_all_off_success");
        }
        else {
          ei_encode_tuple_header(resp, &resp_index, 2);
          ei_encode_atom(resp, &resp_index, "error");
          ei_encode_atom(resp, &resp_index, "proxr_all_off_failed");
        }
    } else errx(EXIT_FAILURE, "unknown command: %s", cmd);

    debug("sending response: %d bytes", resp_index);
    erlcmd_send(resp, resp_index);
}

/**
 * @brief The main function.
 * It waits for data in the buffer and calls the driver.
 */
int proxr_main(int argc, char *argv[])
{
    if (argc != 3)
        errx(EXIT_FAILURE, "Must pass device path");

    struct proxr_info proxr;
    proxr_init(&proxr, argv[2]);

    struct erlcmd handler;
    erlcmd_init(&handler, proxr_handle_request, &proxr);

    for (;;) {
        // Loop forever and process requests from Erlang.
        erlcmd_process(&handler);
    }

    return 1;
}
