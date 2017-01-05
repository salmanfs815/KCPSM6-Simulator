#= KCPSM6 CPU Simulator =#
#= CMPT 276 E100 - Assignment 1 =#

#=

Group: null_ptr

-Salman Siddiqui
-Haider Ilahi
-Eddie Chiu
-Laura Guevara
-Daniel Korin

=#


###########################
#= Variable Declarations =#
###########################

#= program counter; feel fre to manipulate it directly =#
PC = 0 # program counter; indicates which line of code is to be executed

#= flags; feel free to manipulate these directly, or you can also use the toggle functions
invariant: value of ZF or CF is either 0 or 1, nothing else=#
ZF = 0 # zero flag
CF = 0 # carry flag

toggle_zf() = ZF = ZF == 1?0:1
toggle_cf() = CF = CF == 1?0:1

active_bank = "a"

#= call stack will store line numbers of call statements that have been executed
the stack is not to be operated on directly
operations are through call and return functions only =#
call_stack = Int64[]

a = Int64[] # active regbank
b = Int64[] # inactive regbank
for i=1:16
	push!(a, 0)
	push!(b, 0)
end

#The type codeLine represents 1 line of assembly code.
#The attributes are the componenets of the single code line.
type codeLine
	label::ASCIIString
	instr::ASCIIString
	op1::ASCIIString
	op2::ASCIIString
end

type LABEL
	name::ASCIIString
	index::Int64
end

#Declaring the array that stores the a single codeLine per index in order of execution.
arrCode= Array(codeLine, 2048)

#The number of instructions we are loading.
numLines=0

#Declaring an array to check a label's associated index in arrCode.
arrLabel= Array(LABEL, 2048)

#The number of labels, to keep track.
numLabels=0

#Opening the file. f is now associated to this opened text file.
f=open(ARGS[1])

scratch = Int64[];
for i = 1:32
	push!(scratch,0)
end


#####################
   #= Functions =#
#####################

function findRegister(x)
	return parse(Int64,op[2],16)+1
end

#Description: Removes ' ' (space characters) from any string to make parsing easier.
#             Remember that whitespace does not matter in this format of assembly code.
#Post-Condition: There is no whitespace in the returned string.
function strip_all(line)
   result=""
   for char in line
		if char != ' '
			#The string(a,b) funtion concatenates 'a' and 'b' to return "ab".
			result=string(result,char)
		end
	end
	return result
end


#Description: This function returns true if the line of assembly code can be ignored, i.e if its contains only a ';' for a comment or it contains nothing.
function isEmpty(line::ASCIIString)
	if length(line)==0
		#println("EMPTY LINE")
		return true
	elseif length(line)>0
		for i in line
			if isalpha(i)
				#println("NON EMPTY")
				return false
			end
		end
		#println("EMPTY")
		return true
	end
end


#Description: This function gets the label from the line of assembly code.
#Post-Condition: The label string returned preserves the case (upper/lower) of the original line of assembly code.
function getLabel(line::ASCIIString)
	label=""
	if isEmpty(line)
		return label
	end
	i=0
	for char in line
		i+=1
		if char==':'
			break
		end
		label=string(label,char)
	end
	if line[i]!= ':'
		label =""
	end
	label=ASCIIString(label)
	return strip_all(label)
end


#Description: This function gets the instruction component from the line of assembly code.
#             The instr string is all lowercase since this simulator does not require it to be case sensitive.
#Post-Condition: The instr string is all lower case and has no spaces in it.
function getInstr(line::ASCIIString)
	instr=""
	if isEmpty(line)
		return instr
	end
	if getLabel(line) == ""
		i=1
		while line[i]==' '
			i=+1
		end
		while line[i]!=' '
			instr=string(instr,line[i])
			i+=1
		end
	elseif getLabel(line)!=""
		i=1
		while line[i]!= ':'
			i+=1
		end
		i+=1
		while line[i]==' '
			i+=1
		end
		while line[i]!= ' '
			instr=string(instr,line[i])
			i+=1
		end
	end
	instr=ASCIIString(lowercase(instr))
	return instr
end


#Description: This function gets the operand1 component from the line of assembly code.
#             The op1 string is all lowercase since this simulator does not require it to be case sensitive.
#Post-Condition: The op1 string is all lower case and has no spaces in it.
function getOp1(line::ASCIIString)
	op1=""
	if isEmpty(line)
		return op1
	end
	i=1
	while i<length(line)+1
		op1=string(op1,line[i])
		if op1==getLabel(line)
			op1=""
		elseif op1==":"
			op1=""
		elseif strip(lowercase(op1))==getInstr(line)
			op1=""
		end
		i+=1
	end
	op1=strip_all(op1)
	i=1
	while i< length(op1)+1
		if op1[i]==','
			break
		end
		i+=1
	end
	temp=op1
	if i< length(op1)+1 && temp[i]==','
		op1=""
		indx_op1=1
		while indx_op1<i
			op1=string(op1,temp[indx_op1])
			indx_op1+=1
		end
	end
	return ASCIIString(strip(strip_all(lowercase(op1))))
end


#Description: This function gets the operand2 component from the line of assembly code.
#             The op2 string is all lowercase since this simulator does not require it to be case sensitive.
#Post-Condition: The op2 string is all lower case and has no spaces in it.
function getOp2(line::ASCIIString)
	op2=""
	if isEmpty(line)
		return op2
	end
	temp=strip_all(line)
	index=1
	while index<length(temp)+1
		op2=string(op2,temp[index])
		if op2==getLabel(line) && index < length(getLabel(line))+1
			op2=""
		elseif getLabel(line)!= "" && lowercase(op2)==string(':',getInstr(line))
			op2=""
		elseif getLabel(line)=="" && lowercase(op2)==getInstr(line)
			op2=""
		elseif lowercase(op2)==getOp1(line) && index < (length(getLabel(line))+1+length(getInstr(line))+length(getOp1(line))+1)
			op2=""
		elseif op2==","
			op2=""
		end
		index+=1
	end
	return ASCIIString(strip(lowercase(op2)))
end

#Creating the codeLine type and pushing to the array.
#The lines will always be less than 2048 in number so I am not doing any range checks.
for line in eachline(f)
	if !isEmpty(line)
		newLine= codeLine(getLabel(line),getInstr(line),getOp1(line),getOp2(line))
		#println(newLine)
		arrCode[numLines+1]=newLine
		numLines+=1
		#println(arrCode[numLines])
	end
end


#For every label encountered in the arrCode we add that to our list of LABELS and the array(line #) they are found at in arrCode.
for idx in (1:numLines)
	if length(arrCode[idx].label)!=0
		newLabelType=LABEL(arrCode[idx].label,idx)
		arrLabel[numLabels+1]=newLabelType
		numLabels+=1
		#println(arrLabel[numLabels])
	end
end


#Description: This function returns the index of label. This index is the line number where the label can be found in arrCode.
#Post-Condition: It returns a string if the Label doesnt exist.
#ALWAYS CHECK IF THIS VALUE IS VALID AS AN INDEX TO USE IT.
function getLabelIdx(label::ASCIIString)
	for l in arrLabel[1:numLabels]
		if(l.name==label)
			return l.index
		end
	end
	return "NO LABEL FOUND"
end


#= Register Loading =#

#checkRegister will check if the operand is a register
#post Condition: return true if op is a register, false otherwise
function checkRegister(op::ASCIIString)
	regs = []
	for i = 0:15
		push!(regs,"s"*hex(i))
	end
	if op in regs
		return true
	end
	return false
end

function checkRegisterData(op::ASCIIString)
	regs = []
	for i = 0:15
		push!(regs,"(s"*hex(i)*")")
	end
	if op in regs
		return true
	end
	return false
end

function getRegisterData(op::ASCIIString)
	#println(a[parse(Int64,op[3],16)+1])
	return a[parse(Int64,op[3],16)+1]
end

#checkConstant will check if the operand is a register
#post Condition: return true if op is a constant number,
#false otherwise
function checkConstant(op::ASCIIString)

	#ascii char check
	if length(op) == 1 && isascii(op)
		return true
	end
	#hex check
	index = search(op,'\'')
	if index == 0 #didn't find '\'',means op may be hex
		if !isnull(tryparse(Int,"0x" * op))
			return true
		end
	#base 10 and binary check
	else
		if length(op) > index
			testchar = op[index + 1]
			#decimal base 10 check
			if testchar == "d"
				if !isnull(tryparse(Int, op))
					return true
				end
			end
			#binary base 2 check
			if testchar == "b"
				if !isnull(tryparse(Int, op,2))
					return true
				end
			end
		end
	end
	return false
end

#converts op from string to int
#precondition: op is a hex or integer
#postcondition: returned operand as int
function convertToInt(op::ASCIIString)

	#ascii char check
	if length(op) == 1 && isascii(op)
		return convert(Int, op[1])
	end
	#hex check
	index = search(op,'\'')
	if index == 0 #didn't find '\'',means op may be hex
		if !isnull(tryparse(Int,"0x" * op))
			return parse(Int,"0x" * op)
		end
	#base 10 and binary check
	else
		if length(op) > index
			testchar = op[index + 1]
			#decimal base 10 check
			if testchar == 'd'
				if !isnull(tryparse(Int, op[1:index - 1]))
					return parse(Int, op[1:index - 1])
				end
			end
			if testchar == 'b'
				if !isnull(tryparse(Int, op[1:index - 1],2))
					return parse(Int, op[1:index - 1],2)
				end
			end
		end
	end
end

#Load Functions
function load(operand1::ASCIIString, operand2::ASCIIString)
	a[findRegister(operand1)] = a[findRegister(operand2)]
end

function load(operand1::ASCIIString, operand2::Int64)
	a[findRegister(operand1)] = operand2
end

#Star Functions- puts the data in a full register bank into an empty one
function star(operand1::ASCIIString, operand2::ASCIIString)
	b[findRegister(operand1)] = a[findRegister(operand2)]
end

function star(operand1::ASCIIString, operand2::Int64)
	b[findRegister(operand1)] = operand2
end


#= Logical =#

#And Functions
function and(operand1::ASCIIString, operand2::ASCIIString)
	global ZF
	global CF
	a[findRegister(operand1)] = a[findRegister(operand1)] & a[findRegister(operand2)]
	if (a[findRegister(operand1)] == 0)
		ZF = 1
	end
	CF = 0
end

function and(operand1::ASCIIString, operand2::Int64)
	global ZF
	global CF
	a[findRegister(operand1)] = a[findRegister(operand1)] & operand2
	if (a[findRegister(operand1)] == 0)
		ZF = 1
	end
	CF = 0
end

#OR functions
function or(op1::ASCIIString, op2::ASCIIString)
	global ZF
	global CF
	a[findRegister(op1)] = a[findRegister(op1)] | a[findRegister(op2)]
	if (a[findRegister(op1)] == 0)
		ZF = 1
	end
	CF = 0
end

function or(op1::ASCIIString, op2::Int64)
	global ZF
	global CF
	a[findRegister(op1)] = a[findRegister(op1)] | op2
	if (a[findRegister(op1)] == 0)
		ZF = 1
	end
	CF = 0
end

#XOR functions
function xor(op1::ASCIIString, op2::ASCIIString)
	global ZF
	global CF
	a[findRegister(op1)] = a[findRegister(op1)] $ a[findRegister(op2)]
	if (a[findRegister(op1)] == 0)
		ZF = 1
	end
	CF = 0
end

function xor(op1::ASCIIString, op2::Int64)
	global ZF
	global CF
	a[findRegister(op1)] = a[findRegister(op1)] $ op2
	if (a[findRegister(op1)] == 0)
		ZF = 1
	end
	CF = 0
end


#= Arithmetic =#

#ADD functions
function add(op1::ASCIIString, op2::ASCIIString)
	global ZF
	global CF
	CF = 0
	ZF = 0
	a[findRegister(op1)] = a[findRegister(op1)] + a[findRegister(op2)]
	if (a[findRegister(op1)] > 255)
		CF = 1
		a[findRegister(op1)] -= 256
	end
	if (a[findRegister(op1)] == 0)
		ZF = 1
	end
end

function add(op1::ASCIIString, op2::Int64)
	global ZF
	global CF
	CF = 0
	ZF = 0
	a[findRegister(op1)] = a[findRegister(op1)] + op2
	if (a[findRegister(op1)] > 255)
		CF = 1
		a[findRegister(op1)] -= 256
	end
	if (a[findRegister(op1)] == 0)
		ZF = 1
	end
end

#ADDCY functions for multiple add instructions (using carry and zero flags as parameters)
function addcy(op1::ASCIIString, op2::ASCIIString)
	global ZF
	global CF
	a[findRegister(op1)] = a[findRegister(op1)] + a[findRegister(op2)] + CF
	if (a[findRegister(op1)] > 255)
		CF = 1
		a[findRegister(op1)] -= 256
	else 
		CF = 0
	end
	if ((a[findRegister(op1)] == 0) && (ZF == 1))
		ZF = 1
	else 
		ZF = 0
	end
end

function addcy(op1::ASCIIString, op2::Int64)
	global ZF
	global CF
	a[findRegister(op1)] = a[findRegister(op1)] + op2 + CF
	if (a[findRegister(op1)] > 255)
		CF = 1
		a[findRegister(op1)] -= 256
	else 
		CF = 0
	end
	if ((a[findRegister(op1)] == 0) && (ZF == 1))
		ZF = 1
	else 
		ZF = 0
	end
end


#SUB functions
function sub(op1::ASCIIString, op2::ASCIIString)
	global ZF
	global CF
	CF = 0
	ZF = 0
	a[findRegister(op1)] = a[findRegister(op1)] - a[findRegister(op2)]
	if (a[findRegister(op1)] < 0)
		CF = 1
		a[findRegister(op1)] += 256
	end
	if (a[findRegister(op1)] == 0)
		ZF = 1
	end
end

function sub(op1::ASCIIString, op2::Int64)
	global ZF
	global CF
	CF = 0
	ZF = 0
	a[findRegister(op1)] = a[findRegister(op1)] - op2
	if (a[findRegister(op1)] < 0)
		CF = 1
		a[findRegister(op1)] += 256
	end
	if (a[findRegister(op1)] == 0)
		ZF = 1
	end
end

#SUBCY functions for multiple subtarction instructions (using carry and zero flags as parameters)
function subcy(op1::ASCIIString, op2::ASCIIString)
	global ZF
	global CF
	a[findRegister(op1)] = a[findRegister(op1)] - a[findRegister(op2)] - CF
	if (a[findRegister(op1)] < 0)
		CF = 1
		a[findRegister(op1)] += 256
	else 
		CF = 0
	end
	if ((a[findRegister(op1)] == 0) && (ZF == 1))
		ZF = 1
	else 
		ZF = 0
	end
end

function subcy(op1::ASCIIString, op2::Int64)
	global ZF
	global CF
	a[findRegister(op1)] = a[findRegister(op1)] - op2 - CF
	if (a[findRegister(op1)] < 0)
		CF = 1
		a[findRegister(op1)] += 256
	else 
		CF = 0
	end
	if ((a[findRegister(op1)] == 0) && (ZF == 1))
		ZF = 1
	else 
		ZF = 0
	end
end


#= Test and Compare =#

#Carry flag set if number of 1's in the temp are odd
#TO DO- find number of 1's in the temp

function test(op1::ASCIIString, op2::ASCIIString)
	global ZF
	global CF
	ZF = 0
	CF = 0
	temp = a[findRegister(op1)] & a[findRegister(op2)]
	if (temp == 0)
		ZF = 1
	end
end

#Carry flag set if number of 1's in the temp are odd
#TO DO- find number of 1's in the temp
function test(op1::ASCIIString, op2::Int64)
	global ZF
	global CF
	ZF = 0
	CF = 0
	temp = a[findRegister(op1)] & op2
	if (temp == 0)
		ZF = 1
	end
end


#Compare functions- subtract the second operand from the first but only keep the track of the flags
function compare(op1::ASCIIString, op2::ASCIIString)
	global ZF
	global CF
	ZF = 0
	CF = 0
	temp = a[findRegister(op1)] - a[findRegister(op2)]
	if (temp == 0)
		ZF = 1
	end
	if (temp < 0)
		CF = 1
	end
end

function compare(op1::ASCIIString, op2::Int64)
	global ZF
	global CF
	ZF = 0
	CF = 0
	temp = a[findRegister(op1)] - op2
	if (temp == 0)
		ZF = 1
	end
	if (temp < 0)
		CF = 1
	end
end

function comparecy(op1::ASCIIString, op2::ASCIIString)
	global ZF
	global CF
	ZF = 0
	CF = 0
	temp = a[findRegister(op1)] - a[findRegister(op2)] - CF
	if ((temp == 0) && (ZF==1))
		ZF = 1
	end
	if (temp < 0)
		CF = 1
	end
end

function comparecy(op1::ASCIIString, op2::Int64)
	global ZF
	global CF
	ZF = 0
	CF = 0
	temp = a[findRegister(op1)] - op2 - CF
	if ((temp == 0) && (ZF==1))
		ZF = 1
	end
	if (temp < 0)
		CF = 1
	end
end


#= Shift and Rotate =#

#SL0 - shifts left all the contents of the register one bit to left and a 0 is shifted into the LSB.
function sl0(op1::ASCIIString)
	global ZF
	global CF
	sX = a[findRegister(op1)]
	if sX >= 128
		CF = 1
	else
		CF = 0
	end
	sX = sX * 2
	if sX >= 256
		sX -= 256
	end
	if (sX == 0)
		ZF = 1
	end
	a[findRegister(op1)] = sX
end

#SL1 - shifts left one bit 1 is shifted into LSB
function sl1(op1::ASCIIString)
	global ZF
	global CF
	ZF = 0
	sX = a[findRegister(op1)]
	if sX >= 128
		CF = 1
	else
		CF = 0
	end
	sX = sX * 2
	sX += 1
	if sX >= 256
		sX -= 256
	end
	a[findRegister(op1)] = sX
end

#SLX- the last bit of sX is inserted back into the LSB.
function slx(op1::ASCIIString)
	global ZF
	global CF
	sX = a[findRegister(op1)]
	if sX >= 128
		CF = 1
	else
		CF = 0
	end
	lsb = sX % 2 # save least significant bit
	sX = sX * 2
	sX += lsb
	if sX >= 256
		sX -= 256
	end
	if sX == 0
		ZF = 1
	else
		ZF = 0
	end
	a[findRegister(op1)] = sX
end

#SLA - the carry flag is inserted back into LSB.
function sla(op1::ASCIIString)
	global ZF
	global CF
	c = CF # save previous state of CF
	sX = a[findRegister(op1)]
	if sX >= 128
		CF = 1
	else
		CF = 0
	end
	sX = sX * 2
	sX += c
	if sX >= 256
		sX -= 256
	end
	if sX == 0
		ZF = 1
	else
		ZF = 0
	end
	a[findRegister(op1)] = sX
end

#Shift right functions

function sr0(op1::ASCIIString)
	global ZF
	global CF
	sX = a[findRegister(op1)]
	CF = sX % 2
	sX = Int64(ceil((sX/2)-0.5))
	if (sX == 0)
		ZF = 1
	else 
		ZF = 0
	end
	a[findRegister(op1)] = sX
end

function sr1(op1::ASCIIString)
	global ZF
	global CF
	sX = a[findRegister(op1)]
	CF = sX % 2
	sX = Int64(ceil((sX/2)-0.5))
	sX += 128
	if (sX == 0)
		ZF = 1
	else 
		ZF = 0
	end
	a[findRegister(op1)] = sX
end

function srx(op1::ASCIIString)
	global ZF
	global CF
	sX = a[findRegister(op1)]
	msb = 0 # to save most significant bit
	if sX >= 128
		msb = 1
	end
	CF = sX % 2
	sX = Int64(ceil((sX/2)-0.5))
	if msb == 1
		sX += 128
	end
	if (sX == 0)
		ZF = 1
	else 
		ZF = 0
	end
	a[findRegister(op1)] = sX
end

function sra(op1::ASCIIString)
	global ZF
	global CF
	sX = a[findRegister(op1)]
	c = CF # save state of CF
	CF = sX % 2
	sX = Int64(ceil((sX/2)-0.5))
	if c == 1
		sX += 128
	end
	if (sX == 0)
		ZF = 1
	else 
		ZF = 0
	end
	a[findRegister(op1)] = sX
end

#Rotate Instructions
#Rotating each bit to the left
function rl(op1::ASCIIString)
	global ZF
	global CF
	sX = a[findRegister(op1)]
	msb = 0 # most significant bit
	if sX >= 128
		msb = 1
	end
	CF = msb
	sX *= 2
	sX += msb
	if sX >= 256
		sX -= 256
	end
	if (sX == 0)
		ZF = 1
	else 
		ZF = 0
	end
	a[findRegister(op1)] = sX
end

#Rotating each bit to the right
function rr(op1::ASCIIString)
	global ZF
	global CF
	sX = a[findRegister(op1)]
	lsb = sX % 2 # least significant bit
	CF = lsb
	sX = Int64(ceil((sX/2)-0.5))
	if lsb == 1
		sX += 128
	end
	if (sX == 0)
		ZF = 1
	else 
		ZF = 0
	end
	a[findRegister(op1)] = sX
end


#= Register Bank Selection =#

function findRegister(x)
	return parse(Int64,x[2],16)+1
end

#Regbank Functions - choose active bank
function regbank(bank)
	global a
	global b
	global active_bank
	if active_bank == bank
		return  
	end

	active_bank = bank
	a, b = b, a # swap regbanks
	return active_bank
end

#= Input and Output =#
function input(operand1::ASCIIString, operand2::ASCIIString)
	user_input = string(input())
	port_id = operand2
	#check user_input is between 0 and 255
	if (int(user_input)<256) && (int(user_input)>=0)
		#set port_id to be the user_input
		in_port = user_input
		#Daniel's function to find the register index
		a[findRegister(operand1)] = in_port
	else
		#Debugging purpose
		println("error, number not in the range")
	end
end

function output(operand1::ASCIIString, operand2::Int64)
	output_value = a[findRegister(operand1)]
	port_id = operand2
	@printf("%02x %02x\n", port_id, output_value)
	#println(hex(int(port_id))," ",hex(int(output_value)))
end

function outputk(operand1::Int64, operand2::Int64)
	output_value = operand1
	port_id = operand2
	@printf("%02x %02x\n", port_id, output_value)
end

#= Scratch Pad Memory=#

### findRegister for testing purposes
function findReg(op::ASCIIString)
	return parse(Int64,op[2],16)+1
end

function findRegisterData(op::ASCIIString)
	return parse(Int64,op[3],16)+1
end

function store(sx::ASCIIString, sy::ASCIIString)
	#using findReg function: finds sx
	sxIndex = findReg(sx)
	#using findRegisterData function: finds (sy)
	scratchIndex = a[getRegisterData(sy)]
	#println(scratchIndex)
	if 0 <= scratchIndex <= 31
		scratch[scratchIndex + 1] = a[sxIndex]
	else
		print("error: not in range. Location: store sx (sy)")
	end
end

function store(sx::ASCIIString, ss::Int64)

	sxIndex = findReg(sx)
	#println(ss)
	if 0 <= ss <= 31
		#adding 1 because julia starts at 1, while addresses start at 0
		scratch[ss+1] = a[sxIndex]
	else
		print("error: not in range. Location: store sx ss")
	end
end

function fetch(sx::ASCIIString, sy::ASCIIString)

	sxIndex = findReg(sx)
	scratchIndex = a[getRegisterData(sy)]
	if 0 <= scratchIndex <= 31
		#adding 1 because julia starts at 1, while we addresses start at 0
		a[sxIndex] = scratch[scratchIndex + 1]
	else
		print("error: not in range. Location: fetch sx (sy)")
	end
end

function fetch(sx::ASCIIString, ss::Int64)

	sxIndex = findReg(sx)
	#println(ss)
	if 0 <= ss <= 31
		#adding 1 because julia starts at 1, while addresses start at 0
		a[sxIndex] = scratch[ss + 1]
	else
		print("error: not in range. Location: fetch sx ss")
	end
end


#= Jump =#

# unconditional JUMP; returns nothing
function jump(line_number::Int64)
	global PC 
	PC = line_number - 1
end

# unconditional JUMP based on value of sX and sY registers; return nothing
# sX contains the value in the sX register and sY contains the value in the sY register
function jump(sX::Int64, sY::Int64)
	bit_str1 = bin(sX,8)
	bit_str2 = bin(sY,8)
	new_bin = bit_str1[5:8] * bit_str2 # new bit string with lower 4 bits of sX and all 8 bits of sY
	line_number = parse(Int64, new_bin, 2) # convert new_bin into a decimal integer
	jump(line_number)
end

# conditional JUMP; executes jump if flag is set to 1; returns nothing
# precondition: flag is either "Z" or "C" (not case sensitive)
function jump(flag::ASCIIString, line_number::Int64)
	if (uppercase(flag) == "Z" && ZF == 1) || (uppercase(flag) == "C" && CF == 1)
		jump(line_number)
	end
	if (uppercase(flag) == "NZ" && ZF == 0) || (uppercase(flag) == "NC" && CF == 0)
		jump(line_number)
	end
end

#= Subroutines =#

# unconditional CALL; returns nothing
function call(line_number::Int64)
	global PC
	push!(call_stack, PC)
	PC = line_number - 1
end

# unconditional CALL based on value of sX and sY registers; return nothing
# sX contains the value in the sX register and sY contains the value in the sY register
function call(sX::Int64, sY::Int64)
	bit_str1 = bin(sX,8)
	bit_str2 = bin(sY,8)
	new_bin = bit_str1[5:8] * bit_str2 # new bit string with lower 4 bits of sX and all 8 bits of sY
	line_number = parse(Int64, new_bin, 2) # convert new_bin into a decimal integer
	call(line_number)
end

# conditional CALL; executes call if flag is set to 1; returns nothing
# precondition: flag is either "Z" or "C" (not case sensitive)
function call(flag::ASCIIString, line_number::Int64)
	global CF 
	global ZF
	if (uppercase(flag) == "Z" && ZF == 1) || (uppercase(flag) == "C" && CF == 1)
		call(line_number)
	end
	if (uppercase(flag) == "NZ" && ZF == 0) || (uppercase(flag) == "NC" && CF == 0)
		call(line_number)
	end
end


# unconditional RETURN statement
function ret()
	if (isempty(call_stack))
		return # error - empty call stack
	end
	PC = pop!(call_stack) - 1
end

# conditional RETURN based on value of ZF or CF
# precondition: flag is either "C" or "Z"
function ret(flag::ASCIIString)
	global CF 
	global ZF
	if (uppercase(flag) == "Z" && ZF == 1) || (uppercase(flag) == "C" && CF == 1)
		ret()
	end
	if (uppercase(flag) == "NZ" && ZF == 0) || (uppercase(flag) == "NC" && CF == 0)
		ret()
	end
end


function load_return(sX::ASCIIString, value::Int64)
	a[parse(Int64,sX[2],16)+1] = value
	return()
end


#= Version Control =#

function hwbuild(sX::ASCIIString)
	global CF 
	global ZF
	sX_val = a[parse(Int64,sX[2],16)+1]
	CF = 1
	ZF = (sX_val == 0)? 1:0
end


#Function execute will decode the line from the program memory
#and call the appropriate instruction
#Post condition: In case of match, appropriate function is called.
#If failed, then print an error
function execute(line::codeLine) # will fail, I didnt include assembly.jl yet.
	instruction  = line.instr

	#checking whether operands are registers or constants
	op1reg = checkRegister(line.op1)
	op1con = checkConstant(line.op1)
	op1regdata = checkRegisterData(line.op1)
	op2reg = checkRegister(line.op2)
	op2con = checkConstant(line.op2)
	op2regdata = checkRegisterData(line.op2)

	if instruction == "load"
		#check if op1 is register and if op2 is a register or constant
		if op1reg && (op2reg || op2con)
			 #execute load
			 #convert op2 to const if needed
			if(op2con)
				load(line.op1, convertToInt(line.op2))
				return "load,"*line.op1*","*line.op2
			else
				load(line.op1, line.op2)
				return "load,"*line.op1*","*line.op2
			end
		else
			#error: print error/do nothing
		end


	elseif instruction == "and"
		if op1reg && (op2reg || op2con)
			 #execute and
			if(op2con)
				and(line.op1, convertToInt(line.op2))
				return "and,"*line.op1*","*line.op2
			else
				and(line.op1, line.op2)
				return "and,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end


	elseif instruction == "or"
		if op1reg && (op2reg || op2con)
			 #execute or
			if(op2con)
				or(line.op1, convertToInt(line.op2))
				return "or,"*line.op1*","*line.op2
			else
				or(line.op1, line.op2)
				return "or,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end

	elseif instruction == "xor"
		if op1reg && (op2reg || op2con)
			 #execute xor
			if(op2con)
				xor(line.op1, convertToInt(line.op2))
				return "xor,"*line.op1*","*line.op2
			else
				xor(line.op1, line.op2)
				return "xor,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end

	elseif instruction == "add"
		if op1reg && (op2reg || op2con)
			#execute and
			if(op2con)
				add(line.op1, convertToInt(line.op2))
				return "add,"*line.op1*","*line.op2
			else
				add(line.op1, line.op2)
				return "add,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end
	   

	elseif instruction == "addcy"
		if op1reg && (op2reg || op2con)
			#execute addcy
			if(op2con)
				addcy(line.op1, convertToInt(line.op2))
				return "addcy,"*line.op1*","*line.op2
			else
				addcy(line.op1, line.op2)
				return "addcy,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end

	elseif instruction == "sub"
		if op1reg && (op2reg || op2con)
			#execute sub
			if(op2con)
				sub(line.op1, convertToInt(line.op2))
				return "sub,"*line.op1*","*line.op2
			else
				sub(line.op1, line.op2)
				return "sub,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end

	elseif instruction == "subcy"
		if op1reg && (op2reg || op2con)
			#execute subcy
			if(op2con)
				subcy(op1, convertToInt(line.op2))
				return "subcy,"*line.op1*","*line.op2
			else
				subcy(line.op1, line.op2)
				return "subcy,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end

	elseif instruction == "test"
		if op1reg && (op2reg || op2con)
			#execute test
			if(op2con)
				test(op1, convertToInt(line.op2))
				return "test,"*line.op1*","*line.op2
			else
				test(line.op1, line.op2)
				return "test,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end

	elseif instruction == "testcy"
		if op1reg && (op2reg || op2con)
			#execute testcy
			if(op2con)
				testcy(op1, convertToInt(line.op2))
				return "testcy,"*line.op1*","*line.op2
			else
				testcy(line.op1, line.op2)
				return "testcy,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end

	elseif instruction == "compare"
		if op1reg && (op2reg || op2con)
			#execute compare
			if(op2con)
				compare(op1, convertToInt(line.op2))
				return "compare,"*line.op1*","*line.op2
			else
				compare(line.op1, line.op2)
				return "compare,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end

	elseif instruction == "sl0"
		if op1reg 
			sl0(line.op1)
			return "sl0,"*line.op1
		else            
			#error: print error/do nothing
		end

	elseif instruction == "sl1"
		if op1reg 
			sl1(line.op1)
			return "sl1,"*line.op1
		else            
			#error: print error/do nothing
		end

	elseif instruction == "slx"
		if op1reg 
			slx(line.op1)
			return "slx,"*line.op1
		else            
			#error: print error/do nothing
		end

	elseif instruction == "sla"
		if op1reg 
			sla(line.op1)
			return "sla,"*line.op1
		else            
			#error: print error/do nothing
		end
	elseif instruction == "sr0"
		if op1reg 
			sr0(line.op1)
			return "sr0,"*line.op1
		else            
			#error: print error/do nothing
		end
	elseif instruction == "sr1"
		if op1reg 
			sr1(line.op1)
			return "sr1,"*line.op1
		else            
			#error: print error/do nothing
		end
	elseif instruction == "srx"
		if op1reg 
			srx(line.op1)
			return "srx,"*line.op1
		else            
			#error: print error/do nothing
		end
	elseif instruction == "sra"
		if op1reg 
			sra(line.op1)
			return "sra,"*line.op1
		else            
			#error: print error/do nothing
		end
	elseif instruction == "rl"
		if op1reg 
			rl(line.op1)
			return "rl,"*line.op1
		else            
			#error: print error/do nothing
		end
	elseif instruction == "rr"
		if op1reg 
			rr(line.op1)
			return "rr,"*line.op1
		else            
			#error: print error/do nothing
		end
	elseif instruction == "regbank"
		if line.op1 == "a" || line.op1 =="b" 
			regbank(line.op1)
			return "regbank,"*line.op1
		else            
			#error: print error/do nothing
		end
		
	elseif instruction == "star"
		if op1reg && (op2reg || op2con)
			#execute star
			if(op2con)
				star(line.op1, convertToInt(line.op2))
				return "star,"*line.op1*","*line.op2
			else
				star(line.op1, line.op2)
				return "star,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end

	#input not finished: need the data is the register itself
	elseif instruction == "input"
		if op1reg && (op2regdata || op2con)
			#execute input
			if(op2con)
				input(line.op1, convertToInt(op2))
				return "input,"*line.op1*","*line.op2
			else
				input(line.op1, getRegisterData(line.op2))
				return "input,"*line.op1*","*line.op2
			end
		else
			#error: print error/do nothing
		end
	elseif instruction == "output"
		if op1reg && (op2regdata || op2con)
			#execute output
			if(op2con)
				output(line.op1, convertToInt(line.op2))
				return "output,"*line.op1*","*line.op2
			else
				output(line.op1, getRegisterData(line.op2))
				return "output,"*line.op1*","*line.op2
			end

		else
			#error: print error/do nothing
		end
	elseif instruction == "outputk"
		#println("check pt 2")
		#execute outputk   
		outputk(convertToInt(line.op1), convertToInt(line.op2))
		return "outputk,"*line.op1*","*line.op2
	elseif instruction == "store"
		if op1reg && (op2regdata || op2con)
			#execute store
			if(op2con)
				store(line.op1, convertToInt(line.op2))
				return "store,"*line.op1*","*line.op2
			else
				store(line.op1, line.op2)
				return "store,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end    

	elseif instruction == "fetch"
		if op1reg && (op2regdata || op2con)
			#execute fetch
			if(op2con)
				fetch(line.op1, convertToInt(line.op2))
				return "fetch,"*line.op1*","*line.op2
			else
				#println(line)
				fetch(line.op1, line.op2)
				return "fetch,"*line.op1*","*line.op2
			end
		else            
			#error: print error/do nothing
		end      


	elseif instruction == "jump"
		#execute jump
		if line.op1 == "z" 
		   # println("z works")
			if op2con
				jump(line.op1, convertToInt(line.op2))
				return "jump,"*line.op1*","*line.op2
			else
				jump(line.op1, getLabelIdx(line.op2) )
				return "jump,"*line.op1*","*line.op2
			end

		elseif line.op1 == "c" 
			#println("c works")
			if op2con
				jump(line.op1, convertToInt(line.op2))
				return "jump,"*line.op1*","*line.op2
			else
				jump(line.op1, getLabelIdx(line.op2) )
				return "jump,"*line.op1*","*line.op2
			end
		elseif line.op1 == "nz" 
			#println("nz works")
			if op2con
				jump(line.op1, convertToInt(line.op2))
				return "jump,"*line.op1*","*line.op2
			else
				jump(line.op1, getLabelIdx(line.op2) )
				return "jump,"*line.op1*","*line.op2
			end
		elseif line.op1 == "nc"
			#println("nc works")
			if op2con
				jump(line.op1, convertToInt(line.op2))
				return "jump,"*line.op1*","*line.op2
			else
				jump(line.op1, getLabelIdx(line.op2) )
				return "jump,"*line.op1*","*line.op2
			end
		elseif op1con
			#println("constant works")
			jump(convertToInt(line.op1))
			return "jump,"*line.op1
		else
			jump(getLabelIdx(line.op1))
			return "jump,"*line.op1
		end
	elseif instruction == "@jump"
		## op1 = (sx
		## op2 = sy)
		println("entered @jump")
		if(!op1regdata)
			line.op1 = line.op1 * ")" # op1 = (sx)
		end
		if(!op2regdata)
			line.op2 = "(" * line.op2 # op2 = (sy)
		end

		op1regdata = checkRegisterData(line.op1) #check for correctness
		op2regdata = checkRegisterData(line.op2)
		if op1regdata && op2regdata
			#println("@jump works")
			#getRegisterData returns data of (sx), (sy)
			jump(getRegisterData(line.op1), getRegisterData(line.op2))
			return "@jump,"*line.op1*","*line.op2
		else
			#error: print error/do nothing
		end

	elseif instruction == "call"
		#println(line)
		#println(line.op1, line.op2)
		if (line.op1 == "z") || (line.op1 == "c") || (line.op1 == "nz") || (line.op1 == "nc")
		 #   println(line.op1, line.op2, getLabelIdx(line.op2))
			call(line.op1, getLabelIdx(line.op2))
			return "call, "*line.op1*","*line.op2
		elseif line.op2 == ""
		  #  println(line.op1, line.op2)
			call(parse(Int64,line.op1))
			return "call, "*line.op1*","*line.op2
		end
		#=
		if line.op1 == "z" 
			if op2con
				call(line.op1, convertToInt(line.op2))
				return "call,"*line.op1*","*line.op2
			else
				call(line.op1, getLabelIdx(line.op2) )
				return "call,"*line.op1*","*line.op2
			end
		elseif line.op1 == "c" 
			if op2con
				call(line.op1, convertToInt(line.op2))
				return "call,"*line.op1*","*line.op2
			else
				call(line.op1, getLabelIdx(line.op2) )
				return "call,"*line.op1*","*line.op2
			end
		elseif line.op1 == "nz"
			if op2con
				call(line.op1, convertToInt(line.op2))
				return "call,"*line.op1*","*line.op2
			else
				call(line.op1, getLabelIdx(line.op2) )
				return "call,"*line.op1*","*line.op2
			end
		elseif line.op1 == "nc"
			if op2con
				call(line.op1, convertToInt(line.op2))
				return "call,"*line.op1*","*line.op2
			else
				call(line.op1, getLabelIdx(line.op2) )
				return "call,"*line.op1*","*line.op2
			end
		elseif op1con
			#execute call
			call(convertToInt(line.op1))
			return "call,"*line.op1
		else
			jump(getLabelIdx(line.op1))
			return "call,"*line.op1
 
		end
		=#
	elseif instruction == "@call"
		## op1 = (sx
		## op2 = sy)

		if(!op1regdata)
			line.op1 = line.op1 * ")" # op1 = (sx)
		end
		if(!op2regdata)
			line.op2 = "(" * line.op2 # op2 = (sy)
		end

		op1regdata = checkRegisterData(line.op1) #check for correctness
		op2regdata = checkRegisterData(line.op2)
		if op1regdata && op2regdata
			#getRegisterData returns data of (sx), (sy)
			call(getRegisterData(line.op1), getRegisterData(line.op2))
			return "@call,"*line.op1*","*line.op2
		else
			#error: print error/do nothing
		end

	elseif instruction == "return"
		if line.op1 == "z"
			ret(line.op1)
			return "return,"*line.op1
		elseif line.op1 == "c"
			ret(line.op1)
			return "return,"*line.op1
		elseif line.op1 == "nz"
			ret(line.op1)
			return "return,"*line.op1
		elseif line.op1 == "nc"
			ret(line.op1)
			return "return,"*line.op1
		elseif line.op1 == ""
			ret()
			return "return,"
		else
			#error: return argument invalid
		end

	elseif instruction == "load&return"
		if op1reg && op2con
			load_return(line.op1, convertToInt(line.op2))
			return "load&return,"*line.op1*","*line.op2
		else
			#error: print error/do nothing
		end

	elseif instruction == "hwbuild"
		if op1reg
			hwbuild(line.op1)
			return "load&return,"*line.op1
		else
			#error: print error/do nothing
		end
	else
		println("error: instruction not found")
	end
end



############################
#= MAIN PROGRAM EXECUTION =#
############################


#line_num=0
#for instruction in arrCode[1:numLines]
 #   println(arrCode[line_num+1])
#    execute(instruction)
#    line_num+=1

#=
line_num=0
for instruction in arrCode[1:numLines]
	#println(arrCode[line_num+1])
	#println(instruction)
	println(instruction)
	line_num+=1
	#println("Line number:",line_num," has been executed.")
end
=#



line_num=0
deathInstruction = ""
deathJumpCounter = 0;
running = true
#println("PC start is ", PC)
while running
	#println(arrCode[line_num+1])

	PC += 1
	if(PC > numLines)
		#println("PC > numlines, breaking")
		break
	else
		returnedInstruction = execute(arrCode[PC])
		#println(typeof(returnedInstruction))
		#println(returnedInstruction)
		#println("PC after jump is ", PC)

		if typeof(returnedInstruction)!=Void && contains((returnedInstruction), ASCIIString("jump"))
			#println("reached jump equal")
			if deathInstruction == returnedInstruction
				deathJumpCounter +=1
				#println("deathJumpCounter at ", deathJumpCounter)
				#println(deathJumpCounter)
			else
				deathInstruction = returnedInstruction
				#deathJumpCounter = 1
				#println("deathJumpCouunter at")
				#print(deathJumpCounter)
			end
		end

		#println("PC end is ", PC)

		if deathJumpCounter >= 10
			running = false
			#break
		end
		#println("Line number:",line_num," has been executed.")
	end
end

