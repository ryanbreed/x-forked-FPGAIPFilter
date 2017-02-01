#***************************************************************************
#  Copyright (c) 2012 by Michael Fischer. All rights reserved.

#***************************************************************************
# Create Clock
#***************************************************************************
create_clock -period 50MHz  [get_ports CLOCK_50]
create_clock -period 10MHz -name {clk_10} {clk_10}

#***************************************************************************
# Create Generated Clock
#***************************************************************************
derive_pll_clocks

#***************************************************************************
# Set Clock Latency
#***************************************************************************

#***************************************************************************
# Set Clock Uncertainty
#***************************************************************************
derive_clock_uncertainty

#***************************************************************************
# Set Input Delay
#***************************************************************************

#***************************************************************************
# Set Output Delay
#***************************************************************************

#***************************************************************************
# Set Clock Groups
#***************************************************************************

#***************************************************************************
# Set False Path
#***************************************************************************

#***************************************************************************
# Set Multicycle Path
#***************************************************************************

#***************************************************************************
# Set Maximum Delay
#***************************************************************************

#***************************************************************************
# Set Minimum Delay
#***************************************************************************

#***************************************************************************
# Set Input Transition
#***************************************************************************

#***************************************************************************
# Set Load
#***************************************************************************

#*** EOF ***