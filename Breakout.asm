%include "/usr/local/share/csc314/asm_io.inc"

; how frequently to check for input
; 1,000,000 = 1 second
%define TICK_VALUE      100000 ; 1/10 second

; the file that stores the initial state
%define BOARD_FILE 'board.txt'

; how to represent everything
%define WALL_CHARL '#'
%define WALL_CHARR '$'
%define CEILING_CHAR 'x'
%define PLAYER_CHAR '-'
;;%define GOLD_CHAR '$'
%define EMPTY_CHAR ' '
%define BALL_CHAR 'o'
%define RIGHT_BLOCK '@'
%define LEFT_BLOCK '&'
%define CENTER_BLOCK '*'
%define BOTTOM_BLOCK '_'

; the size of the game screen in characters
%define HEIGHT 19
%define WIDTH 49

; the player starting position.
; top left is considered (0,0)
%define STARTX 25
%define STARTY 17

; the ball's starting position
%define BALLXST 25
%define BALLYST 16

; the ball's starting velocity
%define BALLSTVX 0
%define BALLSTVY 0

; these keys do things
%define EXITCHAR 'c'
;;%define UPCHAR 'w'
%define LEFTCHAR 'a'
;;%define DOWNCHAR 's'
%define RIGHTCHAR 'd'
%define LAUNCHCHAR 'f'

segment .data

        ; used to fopen() the board file defined above
        board_file                      db BOARD_FILE,0

        ; used to change the terminal mode
        mode_r                          db "r",0
        raw_mode_on_cmd         db "stty raw -echo",0
        raw_mode_off_cmd        db "stty -raw echo",0

        ; called by system() to clear/refresh the screen
        clear_screen_cmd        db "clear",0

        ; things the program will print
        help_str                        db 13,10,"Controls: ", \
                                                        LEFTCHAR,"=LEFT / ", \
                                                        RIGHTCHAR,"=RIGHT / ", \
                                                        LAUNCHCHAR,"=LAUNCH /",                                                                                                              \
                                                        EXITCHAR,"=EXIT", \
                                                        13,10,10,0
                                                        ;;UPCHAR,"=UP / ", \
                                                        ;;DOWNCHAR,"=DOWN / ", \

        gold_counter    dd      0
        gold_fmt        db      "Points: %d",10,13,0

segment .bss

        ; this array stores the current rendered gameboard (HxW)
        board   resb    (HEIGHT * WIDTH)

        ; these variables store the current player position
        xpos    resd    1
        ypos    resd    1
        bposx   resd    1
        bposy   resd    1

        ; these variables store the movement of the ball- 2 was changed to -1 so                                                                                                              we can multiply to find the opposite direction the ball was previously going
        mox             resd    1       ; no horizontal movement at start      ;                                                                                                              for these values, 2 will be considered moving in a negative direction
        moy             resd    1       ; no vertical movement at start        ;                                                                                                             ; will move vertically by 1 at start until the launch feature is added

segment .text

        global  asm_main
        global  raw_mode_on
        global  raw_mode_off
        global  init_board
        global  render

        extern  system
        extern  putchar
        extern  getchar
        extern  printf
        extern  fopen
        extern  fread
        extern  fgetc
        extern  fclose

        extern  usleep
        extern  fcntl

asm_main:
        enter   0,0
        pusha
        ;***************CODE STARTS HERE***************************

        ; put the terminal in raw mode so the game works nicely
        call    raw_mode_on

        ; read the game board file into the global variable
        call    init_board

        ; set the player at the proper start position
        mov             DWORD [xpos], STARTX
        mov             DWORD [ypos], STARTY
        mov             DWORD [bposx], BALLXST
        mov             DWORD [bposy], BALLYST
        mov             DWORD [mox], BALLSTVX
        mov             DWORD [moy], BALLSTVY


        ; the game happens in this loop
        ; the steps are...
        ;   1. render (draw) the current board
        ;   2. get a character from the user
        ;       3. store current xpos,ypos in esi,edi
        ;       4. update xpos,ypos based on character from user
        ;       5. check what's in the buffer (board) at new xpos,ypos
        ;       6. if it's a wall, reset xpos,ypos to saved esi,edi
        ;       7. otherwise, just continue! (xpos,ypos are ok)
        game_loop:

                push TICK_VALUE
                call usleep
                add esp, 4

                y_up:
                cmp             DWORD [moy], 1  ;; should be 1
                jne             y_dwn
                dec             DWORD [bposy]
                jmp             x_right
                y_dwn:
                cmp             DWORD [moy], -1 ;; should be 2
                jne             x_right
                inc             DWORD [bposy]
                x_right:
                cmp             DWORD [mox], 1
                jne             x_left
                inc             DWORD [bposx]
                jmp             end_ball
                x_left:
                cmp             DWORD [mox], -1
                jne             end_ball
                dec             DWORD [bposx]
;;              dec     DWORD[gold_counter]
                end_ball:

                ; for comparing the ball
                mov             eax, WIDTH
                mul             DWORD [bposy]
                add             eax, [bposx]
                lea             eax, [board + eax]
                comp_ceil:
                cmp             BYTE [eax], CEILING_CHAR
                jne             comp_wal
                        ; hit the ceiling
                        cmp             DWORD [mox], 0
                        jne             ceil_no
                                mov             DWORD [mox], 0
                                jmp             ceil_xi
                        ceil_no:
                        cmp             DWORD [mox], 1
                        jne             ceil_xo
                                mov             DWORD [mox], 1
                                jmp             ceil_xi
                        ceil_xo:
                        cmp             DWORD [mox], -1
                        jne             ceil_xi
                                mov             DWORD [mox], -1
                        ceil_xi:
                        mov             DWORD [moy], -1 ;; should be 2
                        add             DWORD [gold_counter], 10
                comp_wal:
                cmp     BYTE [eax], WALL_CHARL
                jne     comp_war
                        mov     DWORD [mox], 1
                        cmp             DWORD [moy], 1
                        je              wal_mo
                                mov             DWORD [moy], -1
                        jmp             wal_do
                        wal_mo:
                                mov             DWORD [moy], 1
                        wal_do:
                        add             DWORD [gold_counter], 10
                comp_war:
                cmp             BYTE [eax], WALL_CHARR
                jne             comp_right
                        mov             DWORD [mox], -1
                        cmp             DWORD [moy], 1
                        je              war_mo
                                mov             DWORD [moy], -1
                        jmp             war_do
                        war_mo:
                                mov             DWORD [moy], 1
                        war_do:
                        add             DWORD [gold_counter], 10
                comp_right:
                cmp             BYTE [eax], RIGHT_BLOCK
                jne             comp_left
                        cmp             DWORD [mox], 0
                        jne             right_no
                                mov             DWORD [mox], 0
                                jmp             right_xi
                        right_no:
                        cmp             DWORD [mox], 1
                        jne             right_xo
                                mov             DWORD [mox], 1
                                jmp             right_xi
                        right_xo:
                        cmp             DWORD [mox], -1
                        jne             right_xi
                                mov             DWORD [mox], -1
                        right_xi:
                        cmp             DWORD [moy], 1
                        je              right_mo
                                mov             DWORD [moy], 1
                        jmp             right_do
                        right_mo:
                                mov             DWORD [moy], -1
                        right_do:
                        mov             BYTE [eax], EMPTY_CHAR
                        mov             BYTE [eax - 1], EMPTY_CHAR
                        mov             BYTE [eax - 2], EMPTY_CHAR
                        add             DWORD [gold_counter], 100
                comp_left:
                cmp             BYTE [eax], LEFT_BLOCK
                jne             comp_mid
                        cmp             DWORD [mox], 0
                        jne             left_no
                                mov             DWORD [mox], 0
                                jmp             left_xi
                        left_no:
                        cmp             DWORD [mox], 1
                        jne             left_xo
                                mov             DWORD [mox], 1
                                jmp             left_xi
                        left_xo:
                        cmp             DWORD [mox], -1
                        jne             left_xi
                                mov             DWORD [mox], -1
                        left_xi:
                        cmp             DWORD [moy], 1
                        je              left_mo
                                mov             DWORD [moy], 1
                        jmp             left_do
                        left_mo:
                                mov             DWORD [moy], -1
                        left_do:
                        mov             BYTE [eax], EMPTY_CHAR
                        mov             BYTE [eax + 1], EMPTY_CHAR
                        mov             BYTE [eax + 2], EMPTY_CHAR
                        add             DWORD [gold_counter], 100
                comp_mid:
                cmp             BYTE [eax], CENTER_BLOCK
                jne     comp_player
                        cmp             DWORD [mox], 0
                        jne             cent_no
                                mov             DWORD [mox], 0
                                jmp     cent_xi
                        cent_no:
                        cmp             DWORD [mox], 1
                        jne             cent_xo
                                mov             DWORD [mox], 1
                                jmp             cent_xi
                        cent_xo:
                        cmp             DWORD [mox], -1
                        jne             cent_xi
                                mov             DWORD [mox], -1
                        cent_xi:
                        cmp             DWORD [moy], 1
                        je              cent_mo
                                mov             DWORD [moy], 1
                        jmp             cent_do
                        cent_mo:
                                mov             DWORD [moy], -1
                        cent_do:
                        mov             BYTE [eax], EMPTY_CHAR
                        mov             BYTE [eax + 1], EMPTY_CHAR
                        mov             BYTE [eax - 1], EMPTY_CHAR
                        add             DWORD [gold_counter], 1000
                comp_player:    ;; not necessary because fixed below the valid_b                                                                                                             all check
                cmp             BYTE [eax], PLAYER_CHAR
                jne             comp_bot
                        mov             DWORD [mox], 0
                        mov             DWORD [moy], 1  ;; should be 1
                comp_bot:       ;; makes the bottom bar dissappear when the ball                                                                                                              hits it- will then be able to lose
                cmp             BYTE [eax], BOTTOM_BLOCK
                jne             valid_ball
                        cmp             DWORD [mox], 0
                        jne             bot_no
                                mov             DWORD [mox], 0
                                jmp             bot_xi
                        bot_no:
                        cmp             DWORD [mox], 1
                        jne             bot_xo
                                mov             DWORD [mox], 1
                                jmp             bot_xi
                        bot_xo:
                        cmp             DWORD [mox], -1
                        jne             bot_xi
                                mov             DWORD [mox], -1
                        bot_xi:
                        mov             DWORD [moy], 1  ;; should be 1
                        mov             BYTE [eax], EMPTY_CHAR
                        sub             DWORD [gold_counter], 100
                valid_ball:
                cmp             DWORD [bposy], HEIGHT   ; to determine if the ba                                                                                                             ll has left the map
                je game_loop_end
                ; to determine if the ball is touching the player character
                mov     eax, DWORD [bposx]
                cmp             eax, DWORD [xpos]
                jne             help
                mov     eax, DWORD [bposy]
                cmp             eax, DWORD [ypos]
                jne             help
                        chkpl_top:
                        cmp             DWORD [mox], 0
                        jne             play_no
                                mov             DWORD [mox], 0
                                jmp             play_xi
                        play_no:
                        cmp             DWORD [mox], 1
                        jne             play_xo
                                mov             DWORD [mox], 1
                                jmp             play_xi
                        play_xo:
                        cmp             DWORD [mox], -1
                        jne             play_xi
                                mov             DWORD [mox], -1
                        play_xi:
                        cmp             DWORD [moy], 1
                        je              play_mo
                                mov             DWORD [moy], 1
                        jmp             play_do
                        play_mo:
                                mov             DWORD [moy], -1
                        play_do:
                        sub             DWORD [gold_counter], 10
                        jmp             chkpl_done
                help:
                mov     eax, DWORD [bposx]
                mov             ebx, DWORD [xpos]
                add     ebx, 1
                cmp             eax, ebx
                jne             help2
                mov     eax, DWORD [bposy]
                cmp             eax, DWORD [ypos]
                jne             help2
                jmp             chkpl_top
                help2:
                mov     eax, DWORD [bposx]
                mov             ebx, DWORD [xpos]
                sub     ebx, 1
                cmp             eax, ebx
                jne             help3
                mov     eax, DWORD [bposy]
                cmp             eax, DWORD [ypos]
                jne             help3
                jmp             chkpl_top
                help3:
                mov     eax, DWORD [bposx]
                mov             ebx, DWORD [xpos]
                add     ebx, 2
                cmp             eax, ebx
                jne             help4
                mov     eax, DWORD [bposy]
                cmp             eax, DWORD [ypos]
                jne             help4
                jmp             chkpl_top
                help4:
                mov     eax, DWORD [bposx]
                mov             ebx, DWORD [xpos]
                sub     ebx, 2
                cmp             eax, ebx
                jne             chkpl_done
                mov     eax, DWORD [bposy]
                cmp             eax, DWORD [ypos]
                jne             chkpl_done
                jmp             chkpl_top
                chkpl_done:
                ; draw the game board
                call    render

                ; get an action from the user
                call    nonblocking_getchar
                cmp al, -1      ; no character entered
                je game_loop

                ; we will test if the new position is legal
                ; if not, we will restore these
                mov             esi, [xpos]
                mov             edi, [ypos]

                ; choose what to do
                cmp             eax, EXITCHAR
                je              game_loop_end
;;              cmp             eax, UPCHAR
;;              je              move_up
                cmp             eax, LEFTCHAR
                je              move_left
;;              cmp             eax, DOWNCHAR
;;              je              move_down
                cmp             eax, RIGHTCHAR
                je              move_right
                cmp             eax, LAUNCHCHAR
                je              launch_now
                jmp             input_end                       ; or just do not                                                                                                             hing

                ; move the player according to the input character
;;              move_up:
;;                      dec             DWORD [bposy]
;;                      jmp             input_end
                move_left:
                        dec             DWORD [xpos]
                        cmp             DWORD [moy], 0
                                jne     input_end
                        cmp             DWORD [mox], 0
                                jne             input_end
                                dec     DWORD [bposx]
                        jmp             input_end
;;              move_down:
;;                      inc             DWORD [bposy]
;;                      jmp             input_end
                move_right:
                        inc             DWORD [xpos]
                        cmp             DWORD [moy], 0
                                jne     input_end
                        cmp             DWORD [mox], 0
                                jne             input_end
                                inc             DWORD [bposx]
                        jmp             input_end
                launch_now:
                        cmp             DWORD [moy], 0
                                jne     input_end
                        cmp             DWORD [mox], 0
                                jne             input_end
                                mov             DWORD [mox], -1
                                mov             DWORD [moy], 1  ;; should be 1
                input_end:

                ; (W * y) + x = pos
                ; store the current position
                ; compare the current position to the wall character
                mov             eax, WIDTH
                mul             DWORD [ypos]
                add             eax, [xpos]
                lea             eax, [board + eax]
                cmp             BYTE [eax], WALL_CHARR
                jne             left_check
                        ; opps, that was an invalid move, reset
                        mov             DWORD [xpos], esi
                        mov             DWORD [ypos], edi
                left_check:
                cmp             BYTE [eax], WALL_CHARL
                jne             valid_move
                        mov             DWORD [xpos], esi
                        mov             DWORD [ypos], edi
                valid_move:

;;                      cmp BYTE[eax], GOLD_CHAR
;;                      jne not_gold
;;                              add DWORD[gold_counter], 1000
;;                              mov BYTE[eax], EMPTY_CHAR
;;                      not_gold:


        jmp             game_loop
        game_loop_end:

        ; restore old terminal functionality
        call raw_mode_off

        ;***************CODE ENDS HERE*****************************
        popa
        mov             eax, 0
        leave
        ret

; === FUNCTION ===
raw_mode_on:

        push    ebp
        mov             ebp, esp

        push    raw_mode_on_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
raw_mode_off:

        push    ebp
        mov             ebp, esp

        push    raw_mode_off_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
init_board:

        push    ebp
        mov             ebp, esp

        ; FILE* and loop counter
        ; ebp-4, ebp-8
        sub             esp, 8

        ; open the file
        push    mode_r
        push    board_file
        call    fopen
        add             esp, 8
        mov             DWORD [ebp-4], eax

        ; read the file data into the global buffer
        ; line-by-line so we can ignore the newline characters
        mov             DWORD [ebp-8], 0
        read_loop:
        cmp             DWORD [ebp-8], HEIGHT
        je              read_loop_end

                ; find the offset (WIDTH * counter)
                mov             eax, WIDTH
                mul             DWORD [ebp-8]
                lea             ebx, [board + eax]

                ; read the bytes into the buffer
                push    DWORD [ebp-4]
                push    WIDTH
                push    1
                push    ebx
                call    fread
                add             esp, 16

                ; slurp up the newline
                push    DWORD [ebp-4]
                call    fgetc
                add             esp, 4

        inc             DWORD [ebp-8]
        jmp             read_loop
        read_loop_end:

        ; close the open file handle
        push    DWORD [ebp-4]
        call    fclose
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
render:

        push    ebp
        mov             ebp, esp

        ; two ints, for two loop counters
        ; ebp-4, ebp-8
        sub             esp, 8

        ; clear the screen
        push    clear_screen_cmd
        call    system
        add             esp, 4

        ; print the help information
        push    help_str
        call    printf
        add             esp, 4

        ;print the amount of gold
        push    DWORD[gold_counter]
        push    gold_fmt
        call    printf
        add             esp, 4  ;;used to be 8

        ; outside loop by height
        ; i.e. for(c=0; c<height; c++)
        mov             DWORD [ebp-4], 0
        y_loop_start:
        cmp             DWORD [ebp-4], HEIGHT
        je              y_loop_end

                ; inside loop by width
                ; i.e. for(c=0; c<width; c++)
                mov             DWORD [ebp-8], 0
                x_loop_start:
                cmp             DWORD [ebp-8], WIDTH
                je              x_loop_end

                        ; for ball
                        mov             eax, [bposx]
                        cmp     eax, DWORD [ebp-8]
                        jne             pri_play
                        mov             eax, [bposy]
                        cmp             eax, DWORD [ebp-4]
                        jne             pri_play
                                push BALL_CHAR
                                jmp print_end
                        pri_play:
                        ; check if (xpos,ypos)=(x,y)
                        mov             eax, [xpos]
                        cmp             eax, DWORD [ebp-8]
                        jne             print_board
                        mov             eax, [ypos]
                        cmp             eax, DWORD [ebp-4]
                        jne             print_board
                                ; if both were equal, print the player
                                push    PLAYER_CHAR
                                jmp             print_end
                        print_board:
                        mov             eax, [xpos]
                        add             eax, 1
                        cmp             eax, DWORD [ebp-8]
                        jne             print_board2
                        mov             eax, [ypos]
                        cmp             eax, DWORD [ebp-4]
                        jne             print_board2
                                ; if both were equal, print the player
                                push    PLAYER_CHAR
                                jmp             print_end
                        print_board2:
                        mov             eax, [xpos]
                        sub             eax, 1
                        cmp             eax, DWORD [ebp-8]
                        jne             print_board3
                        mov             eax, [ypos]
                        cmp             eax, DWORD [ebp-4]
                        jne             print_board3
                                ; if both were equal, print the player
                                push    PLAYER_CHAR
                                jmp             print_end
                        print_board3:
                        mov             eax, [xpos]
                        add             eax, 2
                        cmp             eax, DWORD [ebp-8]
                        jne             print_board4
                        mov             eax, [ypos]
                        cmp             eax, DWORD [ebp-4]
                        jne             print_board4
                                ; if both were equal, print the player
                                push    PLAYER_CHAR
                                jmp             print_end
                        print_board4:
                        mov             eax, [xpos]
                        sub             eax, 2
                        cmp             eax, DWORD [ebp-8]
                        jne             print_board5
                        mov             eax, [ypos]
                        cmp             eax, DWORD [ebp-4]
                        jne             print_board5
                                ; if both were equal, print the player
                                push    PLAYER_CHAR
                                jmp             print_end
                        print_board5:
                                ; otherwise print whatever's in the buffer
                                mov             eax, [ebp-4]
                                mov             ebx, WIDTH
                                mul             ebx
                                add             eax, [ebp-8]
                                mov             ebx, 0
                                mov             bl, BYTE [board + eax]
                                push    ebx
                        print_end:
                        call    putchar
                        add             esp, 4

                inc             DWORD [ebp-8]
                jmp             x_loop_start
                x_loop_end:

                ; write a carriage return (necessary when in raw mode)
                push    0x0d
                call    putchar
                add             esp, 4

                ; write a newline
                push    0x0a
                call    putchar
                add             esp, 4

        inc             DWORD [ebp-4]
        jmp             y_loop_start
        y_loop_end:

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
nonblocking_getchar:

; returns -1 on no-data
; returns char on succes

; magic values
%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 2048
%define STDIN 0

        push    ebp
        mov             ebp, esp

        ; single int used to hold flags
        ; single character (aligned to 4 bytes) return
        sub             esp, 8

        ; get current stdin flags
        ; flags = fcntl(stdin, F_GETFL, 0)
        push    0
        push    F_GETFL
        push    STDIN
        call    fcntl
        add             esp, 12
        mov             DWORD [ebp-4], eax

        ; set non-blocking mode on stdin
        ; fcntl(stdin, F_SETFL, flags | O_NONBLOCK)
        or              DWORD [ebp-4], O_NONBLOCK
        push    DWORD [ebp-4]
        push    F_SETFL
        push    STDIN
        call    fcntl
        add             esp, 12

        call    getchar
        mov             DWORD [ebp-8], eax

        ; restore blocking mode
        ; fcntl(stdin, F_SETFL, flags ^ O_NONBLOCK
        xor             DWORD [ebp-4], O_NONBLOCK
        push    DWORD [ebp-4]
        push    F_SETFL
        push    STDIN
        call    fcntl
        add             esp, 12

        mov             eax, DWORD [ebp-8]

        mov             esp, ebp
        pop             ebp
