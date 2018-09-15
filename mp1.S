
# mp1.S - missile-command version
# Good luck, and have fun!

.data
	
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h

	NEXT 	  = 0
	X	  = 4
	Y	  = 8
	VX	  = 12
	VY	  = 16
	DEST_X	  = 20
	DEST_Y	  = 24
	EXPLODED  = 28
	C	  = 32

    # Character to draw for an explosion - '@'

	EXPLOSION = 64


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:	.long 0x0	# Head of list pointer
base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byte
mp1_score:		.long 0x0	# Player's current score


# Data private to this  file

base_pic:     	    .string "/^^^\\"	# Picture of a live base
dead_base_pic: 	    .string "xxxxx"	# Picture of a dead base
crosshairs_x:		.long 0x0	# X-position of the crosshairs
crosshairs_y:		.long 0x0	# Y-position of the crosshairs

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
		movl    vmem_base_addr(,1),%edx
		movb    %cl,(%edx,%eax,1)
		ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#	(1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#	(2) Redraw the bases - they may have been overwritten with missiles
#	(3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
		ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:
		movl 8(%esp), %eax
		cmpl 4,%eax
		ja invalid
		jmp *jumptable(,%eax,4)
		
		
invalid:
		movl $-1, %eax
		ret

# ----------------- Functions private to this file -------------------

update_missiles:
		ret

mp1_ioctl_startgame:
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi
		
		movl $0, mp1_missile_list
		movl 0xFFFFFF00, base_alive
		movl $0, mp1_score
		movl $40, crosshairs_x
		movl $12, crosshairs_y
		
		popl %edi
		popl %esi
		popl %ebx
		leave
		ret

mp1_ioctl_addmissile:
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi

		movl 8(%ebp),%edi
		
		#caller save register
		pushl %ecx
		pushl %edx

		#push parameter
		pushl $36
		call mp_1malloc
		addl $4,%esp
		#restore register
		popl %edx
		popl %ecx
		
		cmpl $0,%eax
		je free ########## undone if fail
		
		#caller save registers
		pushl %ecx
		pushl %edx
		pushl %eax
		
		#push parameter		
		pushl $36
		pushl %edi
		pushl %eax
		call mp1_copy_from_user   ##########if fail
		addl $12,%esp
		
		cmpl $0,%eax
		jne free
		#restore registers
		popl %eax
		popl %edx
		popl %ecx
		
		movl mp1_missile_list, (%eax)
		movl %eax,mp1_missile_list
		
		popl %edi
		popl %esi
		popl %ebx
		movl $0,%eax
		leave
		ret

		free:
	#caller save register
		pushl %ecx
		pushl %edx
		pushl %eax
		
		#push parameter
		pushl %eax
		#call free
		call mp_1free
		addl $4,%esp
		
		#restore 
		popl %eax
		popl %edx
		popl %ecx
		
		movl $-1,%eax
		popl %edi
		popl %esi
		popl %ebx
		leave
		ret
		
mp1_ioctl_movexhairs:
		#callee save
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi
		
		movl 8(%ebp),%esi  #get x,y from the stack
		xorl %ebx,%ebx   #clear ebx
		movw %si,%bx	#move low si to bx :x value
		sall $16,%bx
		sarl $16,%bx
		sarl $16,%esi	#shift esi to right 16bits: y value  
		
		addl crosshairs_y,%esi
		cmpl $0,%esi
		jl less_than_zero_y
		cmpl $24,%esi
		jg greater_than_24_y
		jmp update_y   
		
		
		addl %ebx,crosshairs_x
		cmpl $0,%ebx
		jl less_than_zero_x
		cmpl $79,%ebx
		jg greater_than_79_x
		jmp update_x 		
		
		
		less_than_zero_y:
		movl $0,%esi
		jmp update_y
		
		greater_than_24_y:
		movl $24,$esi
		jmp update_y
		
		less_than_zero_x:
		movl $0,$ebx
		jmp update_x
		
		greater_than_79_x:
		movl $79,%ebx
		jmp update_x
		
		update_x:
		movl %ebx,crosshairs_x
		jmp draw
		
		update_y:
		movl %esi,crosshairs_y
		jmp draw
		
		draw:
		imull $80,crosshairs_y,%eax 	#80*y
		addl crosshairs_x,%eax			#80*y+x
		shll $1,%eax					#(80*y+x)*2
		movw 0x2B,%cl					#move "+" into cl
		
		pushl %edx
		call mp1_poke
		popl %edx		
		
		movl $0,%eax					#return 0
		#callee save
		popl %edi
		popl %esi
		popl %ebx
		leave
		ret
		
mp1_ioctl_getstatus:
		#callee save
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi

		movl 8(%ebp),%esi
		
		movl base_alive,%edi
		xorl %ebx,%ebx    #ebx stores the return value
	#eax is the counter
		movl $2,%eax
		loop:
		
		cmpl $0,%eax
		jl loop_done
		addl $-1,%eax
		cmpl $0,%edi
		jl alive_one
		sall $1,%ebx
		jmp move_next
		alive_one:
		addl $1,%ebx
		sall $1,%ebx
		move_next:
		sall $8,%edi
		jmp loop
		
		loop_done:
		sall $16,%ebx    ##make room for score
		movl mp1_score,%ecx
		movw %cx,%bx
		
		
		
		
		#callee save
		popl %edi
		popl %esi
		popl %ebx
		leave
		ret		

mp1_ioctl_endgame:
		ret

jumptable:
.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame
