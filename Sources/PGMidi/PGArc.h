//
//  PGArc.h
//  PGMidi
//

#pragma once

//==============================================================================
#if __has_feature(objc_arc)

#ifdef __cplusplus

template <typename OBJC_TYPE, typename SOURCE_TYPE>
inline
OBJC_TYPE *arc_cast(SOURCE_TYPE *source)
{
    return (__bridge OBJC_TYPE*)source;
}

#endif

#define PGMIDI_DELEGATE_PROPERTY strong


//==============================================================================
#else

#ifdef __cplusplus

template <typename OBJC_TYPE, typename SOURCE_TYPE>
inline
OBJC_TYPE *arc_cast(SOURCE_TYPE *source)
{
    return (OBJC_TYPE*)source;
}

#endif

#define PGMIDI_DELEGATE_PROPERTY assign

#endif
