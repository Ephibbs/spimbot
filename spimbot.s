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

REQUEST_PUZZLE = 0xffff00d0
REQUEST_WORD = 0xffff00d4

smoosh_count: .word 0
.data 
.align 2
fruit_data: .space 260
node_mem: .space 4096
.align 1
puzzle_grid: .space 8192
puzzle_word: .space 128

.text
main:
	li	$t4, TIMER_MASK		# timer interrupt enable bit
	or	$t4, $t4, BONK_MASK	# bonk interrupt bit
	or	$t4, $t4, PUZZLE_MASK	# bonk interrupt bit
	or	$t4, $t4, 1		# global interrupt enable
	mtc0	$t4, $12		# set interrupt mask (Status register)
	li $t1, 0
	sw $t1, VELOCITY
	
	la $a0, puzzle_grid
	sw $a0, REQUEST_PUZZLE
	
loop:
	j loop
	jr	$ra
	
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

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

bonk_interrupt:
	sw	$a1, BONK_ACK		# acknowledge interrupt
	lw $t2, VELOCITY
	li $t1, -1
	mul $t1, $t1, $t2 
	li $t1, -10
	sw	$t1, VELOCITY		# ???

	j	interrupt_dispatch	# see if other interrupts are waiting

puzzle_interrupt:
	sw	$a1, PUZZLE_ACK		# acknowledge interrupt

	la $t1, puzzle_word
	sw $t1, REQUEST_WORD

	
	
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
	
