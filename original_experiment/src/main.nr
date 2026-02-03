fn main(numbers: [u32; 1000]) {
    let mut vec: BoundedVec<u32, 1006> = BoundedVec::from_array([2, 4, 2, 6, 8, 10]);
    for i in numbers {
        if i % 2 == 0 {
            vec.push(i);
        }
    }
}
