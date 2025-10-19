from typing import Optional, Tuple
from dataclasses import dataclass
import numpy as np

@dataclass
class PE:
	a_reg: int = 0
	b_reg: int = 0
	acc: int = 0
	acc_width: int = 32
	frac_bits: int = 8

	def step(self, a_in: Optional[int], b_in: Optional[int]) -> Tuple[int, int]:
		return 0,0

	def read_acc(self) -> int:
		return int(self.acc)

	def is_busy(self) -> bool:
		return (self.a_reg != 0) or (self.b_reg != 0) or (self.acc != 0) 
