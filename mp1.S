
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
		##callee saved
		pushl %ebp  
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi
		####traverse needed

		movl mp1_missile_list, %ebx
		cmpl $0,%ebx
		je done_traverse		##if head is null, jump out of traverse
traverse_loop:		
		#caller save for update_missiles
		pushl %ecx
		pushl %edx
		pushl %eax
		
		pushl %ebx				##push the pointer of current missile in the struct as parameter
		call update_missiles
		#caller tear down for update_missiles
		addl $4,%esp
		popl %eax
		popl %edx
		popl %ecx
		cmpl $0,(%ebx)			#check whether next missile is null		
		je done_traverse
		movl (%ebx),%ebx		#traverse to next missile
		jmp traverse_loop
	
done_traverse:

						#ecx as the base pic carrier
		movl $2,%esi	#set esi as city counter
		movl $4,%edi	#set edi as the char counter
		movl base_alive, %edx 	#put base status into edx
		cmpl $0,%esi
		jl city_loop_done
		cmpl
		cmpl $0,%edi
		jl char_loop_done
		
		call mp1_poke ####redraw city

		call mp1_poke ###redraw crosshairs


		#callee tear down
		popl %edi
		popl %esi
		popl %ebx
		leave
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
		cmpl $4,%eax
		ja invalid
		jmp *jumptable(,%eax,4)
		
		
invalid:
		movl $-1, %eax
		ret

# ----------------- Functions private to this file -------------------

update_missiles:
		##callee saved
		pushl %ebp  
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi
		
		movl 8(%ebp),%ebx  ## get pointer to the missile struct
		movl 4(%ebx),%esi  ## get x
		movl 8(%ebx),%edi  ## get y

		cmpl $0,%esi
		jl out_of_bound
		cmpl $79,%esi
		jg out_of_bound
		cmpl $0,%edi
		jl out_of_bound
		cmpl $24,%edi
		jl out_of_bound
		
		#################################normal
		movl 20(%ebx),%ecx ##get dest_x
		movl 24(%ebx),%edx ##get dest_y

		##check whether at destination
		cmpl %ecx,%esi
		jne check_explosion
		cmpl %edx,%ebx
		je explosion_start

check_explosion:
		movl 28(%ebx),%esi		###move EXPLODED to esi and check whether it's exploding
		cmpl $0,%esi
		je move_missile
		
		
		############call explosion		
		#caller save
explosion_start:

		pushl %ecx
		pushl %edx	

		pushl %ebx
		call missile_explode
		addl $4,%esp
		#caller restore
		popl %edx
		popl %ecx
		cmpl $0,%eax
		je change_counter

		#call mp1_notify_user
		pushl %ecx
		pushl %edx
		pushl %eax

		call mp1_notify_user
		popl %eax
		popl %edx
		popl %ecx			
		
		
change_counter:		
		addl $-1,28(%ebx)
		cmpl $0,28(%ebx)
		je	out_of_bound

		##########draw @
		imull $160,8(%ebx),%esi	
		movl 4(%ebx),%edi
		shll $1,%edi
		addl %edi,%eax	##############################need to store eax somewhere because eax stores return value from missile_explode				
		movb $0x40,%cl					
		pushl %edx
		call mp1_poke
		popl %edx		
		jmp update_return

move_missile:
		imull $160,8(%ebx),%esi	
		movl 4(%ebx),%edi
		shll $1,%edi
		addl %edi,%eax	##############################need to store eax somewhere because eax stores return value from missile_explode				
		movl $0x20,%ecx					
		pushl %edx
		call mp1_poke
		popl %edx		

		movl 4(%ebx),%esi  ## get x
		movl 8(%ebx),%edi  ## get y
		addl 12(%ebx),%esi	##x+vx
		addl 16(%ebx),%edi	##y+vy
		movl %esi,4(%ebx)
		movl %edi,8(%ebx)
		
		imull $160,8(%ebx),%esi	
		movl 4(%ebx),%edi
		shll $1,%edi
		addl %edi,%eax	##############################need to store eax somewhere because eax stores return value from missile_explode				
		movl 32(%ebx),%ecx					
		pushl %edx
		call mp1_poke
		popl %edx		
		jmp update_return

		
out_of_bound:			####if it's out of bound or the exploded counter is 0
		#caller save 
		pushl %ecx
		pushl %edx
		pushl %eax
		
		pushl %ebx	#push parameter of the pointer
		call mp1_missile_remove
		addl $4,%esp
		#caller tear down 
		popl %eax
		popl %edx
		popl %ecx		
		
update_return:
		#callee tear down
		popl %edi
		popl %esi
		popl %ebx
		leave
		ret
		
		
mp1_missile_remove:
		ret


	

mp1_ioctl_startgame:
		pushl %ebp
		movl %esp, %ebp
		pushl %ebx
		pushl %esi
		pushl %edi
		
		movl $0, mp1_missile_list
		movl $0xffffff00, base_alive
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

		movl 8(%ebp),%edi  ##struct pointer
		
		#caller save register
		pushl %ecx
		pushl %edx

		#push parameter
		pushl $36			#36 is the size of struct
		call mp1_malloc
		addl $4,%esp
		#restore register
		popl %edx
		popl %ecx
		
		cmpl $0,%eax
		je malloc_fail ########## if return 0 fail
		
		#caller save registers
		pushl %ecx
		pushl %edx
		pushl %eax
		
		#push parameter		
		pushl $36
		pushl %edi
		pushl %eax
		call mp1_copy_from_user   
		addl $12,%esp
		
		cmpl $0,%eax
		jne free
		#restore registers
		popl %eax
		popl %edx
		popl %ecx
		
		movl mp1_missile_list, %edx
		movl %edx, (%eax)
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
		call mp1_free
		addl $4,%esp
		
		#restore 
		popl %eax
		popl %edx
		popl %ecx

malloc_fail:	
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
		sall $16,%ebx
		sarl $16,%ebx
		sarl $16,%esi	#shift esi to right 16bits: y value  
		
		addl crosshairs_y,%esi
		addl crosshairs_x,%ebx
		cmpl $0,%esi
		jl less_than_zero_y
		cmpl $24,%esi
		jg greater_than_24_y
		 
		cmpl $0,%ebx
		jl less_than_zero_x
		cmpl $79,%ebx
		jg greater_than_79_x
		jmp update		
		
		
less_than_zero_y:
		movl $0,%esi
		jmp update
		
greater_than_24_y:
		movl $24,%esi
		jmp update
		
less_than_zero_x:
		movl $0,%ebx
		jmp update
		
greater_than_79_x:
		movl $79,%ebx
		jmp update
		
update:
		imull $160,crosshairs_y,%eax 	
		movl crosshairs_x,%edi
		shll $1,%edi
		addl %edi,%eax					
		movb $0x20,%cl					
		
		pushl %edx
		call mp1_poke
		popl %edx		


		movl %ebx,crosshairs_x
		movl %esi,crosshairs_y
		jmp draw
		
draw:
		imull $160,crosshairs_y,%eax 	
		movl crosshairs_x,%edi
		shll $1,%edi
		addl %edi,%eax					
		movb $0x2B,%cl					
		
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

		movl 8(%ebp),%esi #esi carries the pointer
		
		movl base_alive,%edi
		xorl %ebx,%ebx    #ebx stores the return value
						  #eax is the counter
		movl $2,%eax
loop:
		
		cmpl $0,%eax	##loop to check the 3 cities
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
		sall $16,%ebx    	##make room for score
		movl mp1_score,%ecx	
		movw %cx,%bx
		
		pushl %ebx		    ##push the score onto the stack
		movl %esp,%ecx
		
		##caller save
		pushl %ecx
		pushl %edx
		pushl %eax
		
		pushl $4
		pushl %ecx			##push the pointer to the score to the stack as parameter (from)
		pushl %esi
		call mp1_copy_to_user
		addl $12,%esp
		
		cmpl $0,%eax
		je copy_to_success
		popl %eax
		movl $-1,%eax
		jmp status_done
		##caller restore
copy_to_success:
		popl %eax
		movl $0,%eax

status_done:
		popl %edx
		popl %ecx		
		
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



 