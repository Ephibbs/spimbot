# syscall constants
PRINT_STRING  = 4

# spimbot constants
VELOCITY      = 0xffff0010
ANGLE         = 0xffff0014
ANGLE_CONTROL = 0xffff0018
BOT_X         = 0xffff0020
BOT_Y         = 0xffff0024
PRINT_INT     = 0xffff0080
OTHER_BOT_X   = 0xffff00a0
OTHER_BOT_Y   = 0xffff00a4

TIMER         = 0xffff001c
TIMER_MASK    = 0x8000
TIMER_ACK     = 0xffff006c

BONK_MASK     = 0x1000
BONK_ACK      = 0xffff0060

PUZZLE_MASK   = 0x800
PUZZLE_ACK    = 0xffff00d8

SMOOSHED_MASK	= 0x2000
SMOOSHED_ACK	= 0xffff0064

REQUEST_PUZZLE = 0xffff00d0
REQUEST_WORD = 0xffff00dc
SUBMIT_SOLUTION = 0xffff00d4

GET_ENERGY = 0xffff00c8
# fruit constants
FRUIT_SCAN	= 0xffff005c
FRUIT_SMASH	= 0xffff0068

smoosh_count: .word 0
.data 
three:	.float	3.0
five:	.float	5.0
PI:	.float	3.141592
F180:	.float  180.0
.align 2
fruit_data: .space 260
node_memory: .space 4096
NODE_SIZE = 12
new_node_address: .word node_memory

.globl directions
directions:
	.word -1  0
	.word  0  1
	.word  1  0
	.word  0 -1

.align 1
puzzle_grid: .space 8192
puzzle_word: .space 128

.text
main:
	li	$t4, TIMER_MASK		# timer interrupt enable bit
	or	$t4, $t4, BONK_MASK	# bonk interrupt bit
	or	$t4, $t4, PUZZLE_MASK	# bonk interrupt bit
	or	$t4, $t4, SMOOSHED_MASK	# smoosh interrupt bit
	or	$t4, $t4, 1		# global interrupt enable
	mtc0	$t4, $12		# set interrupt mask (Status register)
	#check if other bot exists--existance in t7 reg 1->true 0->false
	li $t1, 0
	sw $t1, VELOCITY
	li $t8, 1	
	lw $t0, OTHER_BOT_X
	li $t7, 1
	li $s7, 0
	li $s6, 0
	beq	$t0, 0, no_bot
	j loop

no_bot:

start:
	li	$t0, 90
	sw	$t0, ANGLE
	li 	$t0, 1
	sw 	$t0, ANGLE_CONTROL
	li	$t0, 10
	sw	$t0, VELOCITY
	lw	$t0, BOT_Y
	blt	$t0, 290, start
	li	$t0, 0
	sw	$t0, ANGLE
	li 	$t0, 1
	sw 	$t0, ANGLE_CONTROL

sel:
	la	$s3, fruit_data
	sw	$s3, FRUIT_SCAN
	move	$s4, $s3	#keep copy of pointer for if new fruit
	lw	$t2, 0($s3)	#get id
	beq	$t2, 0, sel	#if not found, get new one
	sub	$s3, $s3, 16

find_fruit:
	add	$s3, $s3, 16	
	lw	$t2, 0($s3)	#get id
	beq	$t2, 0, find_new_fruit	#if not found, get new one
	beq	$t2, $s6, next_step	#if right id, move on
	j	find_fruit

find_new_fruit:
	add	$s3, $s4, 0	
	lw	$s6, 4($s3)	#point_count
	bne	$s6, 10, next_step
	add	$s4, $s4, 16
	j	find_new_fruit

next_step:
	lw	$s6, 0($s3)	#point_count
	lw	$t2, 8($s3) 	#fruit-x
	lw 	$s0, GET_ENERGY
	bge	$s7, 1, go_smash_no_bot
	beq $t8, 1, puz_req_no_bot

follow_fruit:
	lw	$t3, BOT_X

	sub	$t4, $t2, $t3
	beq	$t4, $0, stop
	slt 	$t5, $t4, 10
	sgt 	$t6, $t4, -10
	and 	$t7, $t5, $t6
	beq	$t7, 1, update
	blt	$t4, $0, go_left
	bgt	$t4, $0, go_right

stop:
	li	$t4, 0
	j	update
go_left:
	li	$t4, -10
	j	update
go_right:
	li	$t4, 10
	j	update
update:
	sw	$t4, VELOCITY
	j	sel

get_back:
	li	$t0, 10
	sw	$t0, VELOCITY
	lw	$t0, BOT_Y
	ble	$t0, 270, start
	j	get_back

loop:
	bge $s7, 5, go_smash
	beq $t8, 1, puz_req
	beq $t7, 1 follow
	#othewise collect fruit
	j loop

follow:
	lw $t0, OTHER_BOT_X
	lw $t1, BOT_X
	lw $t2, OTHER_BOT_Y
	lw $t3, BOT_Y
	sub $a0, $t0, $t1	
	sub $a1, $t2, $t3	
	sub $a1, $a1, 10
	j sb_arctan

follow2:
	move $t1, $s0
	sw $t1, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL
	li $t1, 10
	sw $t1, VELOCITY
	j loop

move_pos:
	li $t1, 10
	sw $t1, VELOCITY

puz_req:
	la $t9, puzzle_grid
	sw $t9, REQUEST_PUZZLE
	li $t8, 0
	j loop

rev_pos:
	lw $t2, VELOCITY
	bge $t2, 0, loop
	li $t1, -1
	mul $t1, $t1, $t2 
	sw	$t1, VELOCITY		# ???
	j loop

rev_neg:
	lw $t2, VELOCITY
	ble $t2, 0, loop
	li $t1, -1
	mul $t1, $t1, $t2 
	sw	$t1, VELOCITY		# ???
	j loop

puz_req_no_bot:
	la $t9, puzzle_grid
	sw $t9, REQUEST_PUZZLE
	li $t8, 0
	j follow_fruit

go_smash_no_bot:
	li $t1, 90
	sw $t1, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL
	li $t1, 10
	sw $t1, VELOCITY
	j go_to_smash_site_no_bot

go_to_smash_site_no_bot:
	lw $t1, ANGLE
	beq $t1, 270, start
	j go_to_smash_site_no_bot

go_smash:
	li $t1, 90
	sw $t1, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL
	li $t1, 10
	sw $t1, VELOCITY
	j go_to_smash_site

go_to_smash_site:
	lw $t1, ANGLE
	beq $t1, 270, loop
	j go_to_smash_site

# -----------------------------------------------------------------------
# sb_arctan - computes the arctangent of y / x
# $a0 - x
# $a1 - y
# returns the arctangent
# -----------------------------------------------------------------------

sb_arctan:
	li	$s0, 0		# angle = 0;

	abs	$t0, $a0	# get absolute values
	abs	$t1, $a1
	ble	$t1, $t0, no_TURN_90	  

	## if (abs(y) > abs(x)) { rotate 90 degrees }
	move	$t0, $a1	# int temp = y;
	neg	$a1, $a0	# y = -x;      
	move	$a0, $t0	# x = temp;    
	li	$s0, 90		# angle = 90;  

no_TURN_90:
	bgez	$a0, pos_x 	# skip if (x >= 0)

	## if (x < 0) 
	add	$s0, $s0, 180	# angle += 180;

pos_x:
	mtc1	$a0, $f0
	mtc1	$a1, $f1
	cvt.s.w $f0, $f0	# convert from ints to floats
	cvt.s.w $f1, $f1
	
	div.s	$f0, $f1, $f0	# float v = (float) y / (float) x;

	mul.s	$f1, $f0, $f0	# v^^2
	mul.s	$f2, $f1, $f0	# v^^3
	l.s	$f3, three	# load 5.0
	div.s 	$f3, $f2, $f3	# v^^3/3
	sub.s	$f6, $f0, $f3	# v - v^^3/3

	mul.s	$f4, $f1, $f2	# v^^5
	l.s	$f5, five	# load 3.0
	div.s 	$f5, $f4, $f5	# v^^5/5
	add.s	$f6, $f6, $f5	# value = v - v^^3/3 + v^^5/5

	l.s	$f8, PI		# load PI
	div.s	$f6, $f6, $f8	# value / PI
	l.s	$f7, F180	# load 180.0
	mul.s	$f6, $f6, $f7	# 180.0 * value / PI

	cvt.w.s $f6, $f6	# convert "delta" back to integer
	mfc1	$t0, $f6
	add	$s0, $s0, $t0	# angle += delta
	
	j follow2
	
####################
#####Interrupts#####
####################
	
.kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 8	# space for two registers
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"
	
.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		# Get some free registers                  
	sw	$a1, 4($k0)		# by storing them to a global variable     

	mfc0	$k0, $13		# Get Cause register                       
	srl	$a0, $k0, 2                
	and	$a0, $a0, 0xf		# ExcCode field                            
	bne	$a0, 0, non_intrpt         

interrupt_dispatch:			# Interrupt:                             
	mfc0	$k0, $13		# Get Cause register, again                 
	beq	$k0, 0, done		# handled all outstanding interrupts     

	and	$a0, $k0, BONK_MASK	# is there a bonk interrupt?                
	bne	$a0, 0, bonk_interrupt   

	and	$a0, $k0, TIMER_MASK	# is there a timer interrupt?
	bne	$a0, 0, timer_interrupt
	
	and	$a0, $k0, PUZZLE_MASK	# is there a puzzle interrupt?                
	bne	$a0, 0, puzzle_interrupt   
	
	and	$a0, $k0, SMOOSHED_MASK
	bne	$a0, 0, smoosh_interrupt

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

bonk_interrupt:
	#sw	$a1, BONK_ACK		# acknowledge interrupt
	#j	interrupt_dispatch	# see if other interrupts are waiting

	sw	$0, VELOCITY

	lw	$t0, BOT_Y
	blt	$t0, 270, bonk_ret
	
	smash_fruit:
		beq $0, $s7, finished_smashing
		
		sw $s7, FRUIT_SMASH
		
		sub $s7, $s7, 1
		j 	smash_fruit

	finished_smashing:
		li	$t0, 270
		sw	$t0, ANGLE
		li 	$t1, 1
		sw 	$t1, ANGLE_CONTROL

	bonk_ret:
		sw	$a1, BONK_ACK		# acknowledge interrupt
		j	interrupt_dispatch	# see if other interrupts are waiting

puzzle_interrupt:
	sw	$a1, PUZZLE_ACK		# acknowledge interrupt
	
	la $t0, node_memory
	sw $t0, new_node_address

	la $a1, puzzle_word
	sw $a1, REQUEST_WORD

	lw $t1, 0($t9)		#num_rows
	lw $t2, 4($t9)		#num_cols
	
	mul $t3, $t1, $t2	

	bge $t3, 3000, skip

	add $a0, $t9, 8 	# pointer to puzzle

	jal solve_puzzle
	beq $v0, 0, interrupt_dispatch
	sw $v0, SUBMIT_SOLUTION	

	skip:
	li $t8, 1
	j	interrupt_dispatch	# see if other interrupts are waiting

smoosh_interrupt:
	sw	$a1, SMOOSHED_ACK		# acknowledge interrupt
	add	$s7, $s7, 1
	j	interrupt_dispatch	# see if other interrupts are waiting

timer_interrupt:
	sw	$a1, TIMER_ACK		# acknowledge interrupt

	#li	$t0, 90			# ???
	#sw	$t0, ANGLE		# ???
	#sw	$zero, ANGLE_CONTROL	# ???

	lw	$v0, TIMER		# current time
	add	$v0, $v0, 50000  
	sw	$v0, TIMER		# request timer in 50000 cycles

	j	interrupt_dispatch	# see if other interrupts are waiting

non_intrpt:				# was some non-interrupt
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)		# Restore saved registers
	lw	$a1, 4($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret

####################
##### Set Node #####
####################

.globl set_node
set_node:
	sub	$sp, $sp, 16
	sw	$ra, 0($sp)
	sw	$a0, 4($sp)
	sw	$a1, 8($sp)
	sw	$a2, 12($sp)

	jal	allocate_new_node
	lw	$a0, 4($sp)	# row
	sw	$a0, 0($v0)	# node->row = row
	lw	$a1, 8($sp)	# col
	sw	$a1, 4($v0)	# node->col = col
	lw	$a2, 12($sp)	# next
	sw	$a2, 8($v0)	# node->next = next

	lw	$ra, 0($sp)
	add	$sp, $sp, 16
	jr	$ra

#####################
####Set Neighbors####
#####################

.globl search_neighbors
search_neighbors:
	bne	$a1, 0, sn_main		# !(word == NULL)
	li	$v0, 0			# return NULL (data flow)
	jr	$ra			# return NULL (control flow)

sn_main:
	sub	$sp, $sp, 36
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)

	move	$s0, $a0		# puzzle
	move	$s1, $a1		# word
	move	$s2, $a2		# row
	move	$s3, $a3		# col
	li	$s4, 0			# i

sn_loop:
	mul	$t0, $s4, 8		# i * 8
	lw	$t1, directions($t0)	# directions[i][0]
	add	$s5, $s2, $t1		# next_row
	lw	$t1, directions+4($t0)	# directions[i][1]
	add	$s6, $s3, $t1		# next_col

	#lw $t0, 0($t9)
	#div	$s5, $t0
	#mfhi $s5
	#lw $t0, 4($t9)
	#div	$s6, $t0
	#mfhi $s6

	ble	$s5, -1, sn_next	# !(next_row > -1)
	#lw	$t0, num_rows
	lw $t0, 0($t9)
	bge	$s5, $t0, sn_next	# !(next_row < num_rows)
	ble	$s6, -1, sn_next	# !(next_col > -1)
	#lw	$t0, num_cols
	lw $t0, 4($t9)
	bge	$s6, $t0, sn_next	# !(next_col < num_cols)

	mul	$t0, $s5, $t0		# next_row * num_cols
	add	$t0, $t0, $s6		# next_row * num_cols + next_col
	add	$s7, $s0, $t0		# &puzzle[next_row * num_cols + next_col]
	lb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col]
	lb	$t1, 0($s1)		# *word
	bne	$t0, $t1, sn_next	# !(puzzle[next_row * num_cols + next_col] == *word)

	lb	$t0, 1($s1)		# *(word + 1)
	bne	$t0, 0, sn_search	# !(*(word + 1) == '\0')
	move	$a0, $s5		# next_row
	move	$a1, $s6		# next_col
	li	$a2, 0			# NULL
	jal	set_node		# $v0 will contain return value
	j	sn_return

sn_search:
	li	$t0, '*'
	sb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col] = '*'
	move	$a0, $s0		# puzzle
	add	$a1, $s1, 1		# word + 1
	move	$a2, $s5		# next_row
	move	$a3, $s6		# next_col
	jal	search_neighbors
	lb	$t0, 0($s1)		# *word
	sb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col] = *word
	beq	$v0, 0, sn_next		# !next_node
	move	$a0, $s5		# next_row
	move	$a1, $s6		# next_col
	move	$a2, $v0		# next_node
	jal	set_node
	j	sn_return

sn_next:
	add	$s4, $s4, 1		# i++
	blt	$s4, 4, sn_loop		# i < 4
	
	li	$v0, 0			# return NULL (data flow)

sn_return:
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	lw	$s5, 24($sp)
	lw	$s6, 28($sp)
	lw	$s7, 32($sp)
	add	$sp, $sp, 36
	jr	$ra

search_cell:
	sub	$sp, $sp, 36
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)
	sw	$s5, 24($sp)
	sw	$s6, 28($sp)
	sw	$s7, 32($sp)

	move	$s0, $a0		# puzzle
	move	$s1, $a1		# word
	move	$s2, $a2		# row
	move	$s3, $a3		# col
	li	$s4, 0			# i

	mul	$t0, $s4, 8		# i * 8
	lw	$t1, directions($t0)	# directions[i][0]
	add	$s5, $s2, $t1		# next_row
	lw	$t1, directions+4($t0)	# directions[i][1]
	add	$s6, $s3, $t1		# next_col

	ble	$s5, -1, sn_next	# !(next_row > -1)
	#lw	$t0, num_rows
	lw $t0, 0($t9)
	bge	$s5, $t0, sn_next	# !(next_row < num_rows)
	ble	$s6, -1, sn_next	# !(next_col > -1)
	#lw	$t0, num_cols
	lw $t0, 4($t9)
	bge	$s6, $t0, sn_next	# !(next_col < num_cols)

	mul	$t0, $s5, $t0		# next_row * num_cols
	add	$t0, $t0, $s6		# next_row * num_cols + next_col
	add	$s7, $s0, $t0		# &puzzle[next_row * num_cols + next_col]
	lb	$t0, 0($s7)		# puzzle[next_row * num_cols + next_col]
	lb	$t1, 0($s1)		# *word
	bne	$t0, $t1, sn_next	# !(puzzle[next_row * num_cols + next_col] == *word)

	lb	$t0, 1($s1)		# *(word + 1)
	bne	$t0, 0, sn_search	# !(*(word + 1) == '\0')
	move	$a0, $s5		# next_row
	move	$a1, $s6		# next_col
	li	$a2, 0			# NULL
	jal	set_node		# $v0 will contain return value
	j	sn_return

.globl allocate_new_node
allocate_new_node:
	lw	$v0, new_node_address
	add	$t0, $v0, NODE_SIZE
	sw	$t0, new_node_address
	jr	$ra

.globl solve_puzzle
solve_puzzle:
	sub	$sp, $sp, 24
	sw	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)
	sw	$s2, 12($sp)
	sw	$s3, 16($sp)
	sw	$s4, 20($sp)

	move	$s0, $a0		# puzzle
	move	$s1, $a1		# word

	lb	$t0, 0($s1)		# word[0]
	beq	$t0, 0, sp_done		# word[0] == '\0'

	li	$s2, 0			# row = 0

sp_row_for:
	lw $t0, 0($t9)
	bge	$s2, $t0, sp_false	# !(row < num_rows)

	li	$s3, 0			# col = 0

sp_col_for:
	lw $t0, 4($t9)
	bge	$s3, $t0, sp_row_next	# !(col < num_cols)

	move	$a0, $s0		# puzzle
	move	$a1, $s2		# row
	move	$a2, $s3		# col
	jal	get_char		# $v0 = current_char
	lb	$t0, 0($s1)		# target_char = word[0]
	bne	$v0, $t0, sp_col_next	# !(current_char == target_char)

	move	$a0, $s0		# puzzle
	move	$a1, $s2		# row
	move	$a2, $s3		# col
	li	$a3, '*'
	jal	set_char

	move	$a0, $s0		# puzzle
	add	$a1, $s1, 1		# word + 1
	move	$a2, $s2		# row
	move	$a3, $s3		# col
	jal	search_neighbors
	move	$s4, $v0		# exist
	move	$a0, $s2		# row
	move	$a1, $s3		# col
	move $a2, $s4
	jal set_node
	move	$s4, $v0		# exist

	move	$a0, $s0		# puzzle
	move	$a1, $s2		# row
	move	$a2, $s3		# col
	lb	$a3, 0($s1)		# word[0]
	jal	set_char

	bne	$s4, 0, sp_done		# if (exist)

sp_col_next:
	add	$s3, $s3, 1		# col++
	j	sp_col_for

sp_row_next:
	add	$s2, $s2, 1		# row++
	j	sp_row_for

sp_false:
	li $s4, 0

sp_done:
	move $v0, $s4
	lw	$ra, 0($sp)
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	lw	$s4, 20($sp)
	add	$sp, $sp, 24
	jr	$ra

.globl get_char
get_char:
	lw $t2, 4($t9)
	mul	$v0, $a1, $t2	# row * num_cols
	add	$v0, $v0, $a2	# row * num_cols + col
	add	$v0, $a0, $v0	# &array[row * num_cols + col]
	move	$t1, $v0
	lb	$v0, 0($v0)	# array[row * num_cols + col]
	
	#lb	$0, 4($t1) 	# Prefetch next four elements
	#add	$t1, $t1, $t2
	#lb	$0, 0($t1) 	# Prefetch four elements one row below

	jr	$ra

.globl set_char
set_char:
	lw $v0, 4($t9)
	mul	$v0, $a1, $v0	# row * num_cols
	add	$v0, $v0, $a2	# row * num_cols + col
	add	$v0, $a0, $v0	# &array[row * num_cols + col]
	sb	$a3, 0($v0)	# array[row * num_cols + col] = c
	jr	$ra


