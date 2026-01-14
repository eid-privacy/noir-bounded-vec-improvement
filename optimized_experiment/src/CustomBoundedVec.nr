use std::{cmp::Eq, convert::From, runtime::is_unconstrained, static_assert};

pub struct OptimizedBoundedVec<T, let MaxLen: u32> {
    storage: [T; MaxLen],
    len: u32,
}

impl<T, let MaxLen: u32> OptimizedBoundedVec<T, MaxLen> {
    pub fn new() -> Self {
        let zeroed = std::mem::zeroed();
        OptimizedBoundedVec { storage: [zeroed; MaxLen], len: 0 }
    }

    pub fn get(self, index: u32) -> T {
        assert(index < self.len, "Attempted to read past end of OptimizedBoundedVec");
        self.get_unchecked(index)
    }

    pub fn get_unchecked(self, index: u32) -> T {
        self.storage[index]
    }

    pub fn set(&mut self, index: u32, value: T) {
        assert(index < self.len, "Attempted to write past end of OptimizedBoundedVec");
        self.set_unchecked(index, value)
    }

    pub fn set_unchecked(&mut self, index: u32, value: T) {
        self.storage[index] = value;
    }

    pub fn push(&mut self, elem: T) {
        self.storage[self.len] = elem;
        self.len += 1;
    }

    pub fn len(self) -> u32 {
        self.len
    }

    pub fn max_len(_self: OptimizedBoundedVec<T, MaxLen>) -> u32 {
        MaxLen
    }

    pub fn storage(self) -> [T; MaxLen] {
        self.storage
    }

    pub fn extend_from_array<let Len: u32>(&mut self, array: [T; Len]) {
        let new_len = self.len + array.len();
        assert(new_len <= MaxLen, "extend_from_array out of bounds");
        for i in 0..array.len() {
            self.storage[self.len + i] = array[i];
        }
        self.len = new_len;
    }

    pub fn extend_from_slice(&mut self, slice: [T]) {
        let new_len = self.len + slice.len();
        assert(new_len <= MaxLen, "extend_from_slice out of bounds");
        for i in 0..slice.len() {
            self.storage[self.len + i] = slice[i];
        }
        self.len = new_len;
    }

    pub fn extend_from_bounded_vec<let Len: u32>(&mut self, vec: BoundedVec<T, Len>) {
        let append_len = vec.len();
        let new_len = self.len + append_len;
        assert(new_len <= MaxLen, "extend_from_bounded_vec out of bounds");

        let mut exceeded_len = false;
        for i in 0..Len {
            exceeded_len |= i == append_len;
            if !exceeded_len {
                self.storage[self.len + i] = vec.get_unchecked(i);
            }
        }

        self.len = new_len;
    }

    pub fn from_array<let Len: u32>(array: [T; Len]) -> Self {
        static_assert(Len <= MaxLen, "from array out of bounds");
        let mut vec: OptimizedBoundedVec<T, MaxLen> = OptimizedBoundedVec::new();
        vec.extend_from_array(array);
        vec
    }

    pub fn pop(&mut self) -> T {
        assert(self.len > 0, "cannot pop from an empty vector");
        self.len -= 1;

        let elem = self.storage[self.len];
        self.storage[self.len] = std::mem::zeroed();
        elem
    }

    pub fn any<Env>(self, predicate: fn[Env](T) -> bool) -> bool {
        let mut ret = false;
        if is_unconstrained() {
            for i in 0..self.len {
                ret |= predicate(self.storage[i]);
            }
        } else {
            let mut exceeded_len = false;
            for i in 0..MaxLen {
                exceeded_len |= i == self.len;
                if !exceeded_len {
                    ret |= predicate(self.storage[i]);
                }
            }
        }
        ret
    }

    pub fn map<U, Env>(self, f: fn[Env](T) -> U) -> OptimizedBoundedVec<U, MaxLen> {
        let mut ret = OptimizedBoundedVec::new();
        ret.len = self.len();

        if is_unconstrained() {
            for i in 0..self.len() {
                ret.storage[i] = f(self.get_unchecked(i));
            }
        } else {
            for i in 0..MaxLen {
                if i < self.len() {
                    ret.storage[i] = f(self.get_unchecked(i));
                }
            }
        }

        ret
    }

    pub fn mapi<U, Env>(self, f: fn[Env](u32, T) -> U) -> OptimizedBoundedVec<U, MaxLen> {
        let mut ret = OptimizedBoundedVec::new();
        ret.len = self.len();

        if is_unconstrained() {
            for i in 0..self.len() {
                ret.storage[i] = f(i, self.get_unchecked(i));
            }
        } else {
            for i in 0..MaxLen {
                if i < self.len() {
                    ret.storage[i] = f(i, self.get_unchecked(i));
                }
            }
        }

        ret
    }

    pub fn for_each<Env>(self, f: fn[Env](T) -> ()) {
        if is_unconstrained() {
            for i in 0..self.len() {
                f(self.get_unchecked(i));
            }
        } else {
            for i in 0..MaxLen {
                if i < self.len() {
                    f(self.get_unchecked(i));
                }
            }
        }
    }

    pub fn for_eachi<Env>(self, f: fn[Env](u32, T) -> ()) {
        if is_unconstrained() {
            for i in 0..self.len() {
                f(i, self.get_unchecked(i));
            }
        } else {
            for i in 0..MaxLen {
                if i < self.len() {
                    f(i, self.get_unchecked(i));
                }
            }
        }
    }

    pub fn from_parts(mut array: [T; MaxLen], len: u32) -> Self {
        assert(len <= MaxLen);
        let zeroed = std::mem::zeroed();

        if is_unconstrained() {
            for i in len..MaxLen {
                array[i] = zeroed;
            }
        } else {
            for i in 0..MaxLen {
                if i >= len {
                    array[i] = zeroed;
                }
            }
        }

        OptimizedBoundedVec { storage: array, len }
    }

    pub fn from_parts_unchecked(array: [T; MaxLen], len: u32) -> Self {
        assert(len <= MaxLen);
        OptimizedBoundedVec { storage: array, len }
    }
}

impl<T, let MaxLen: u32> Eq for OptimizedBoundedVec<T, MaxLen>
where
    T: Eq,
{
    fn eq(self, other: OptimizedBoundedVec<T, MaxLen>) -> bool {
        if self.len == other.len {
            self.storage == other.storage
        } else {
            false
        }
    }
}

impl<T, let MaxLen: u32, let Len: u32> From<[T; Len]> for OptimizedBoundedVec<T, MaxLen> {
    fn from(array: [T; Len]) -> OptimizedBoundedVec<T, MaxLen> {
        OptimizedBoundedVec::from_array(array)
    }
}
