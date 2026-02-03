mod CustomBoundedVec;
use CustomBoundedVec::OptimizedBoundedVec;

fn main(numbers: [u32; 1000]) {
    let mut vec: OptimizedBoundedVec<u32, 1006> =
        OptimizedBoundedVec::from_array([2, 4, 2, 6, 8, 10]);

    let mut counter: u32 = 0;
    for i in numbers {
        if i % 2 == 0 {
            vec.set_unchecked(vec.len() + counter, i);
        }
        counter += 1;
    }
    vec.set_len(vec.len() + counter);
}
