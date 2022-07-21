import invariant from 'tiny-invariant'

/**
 * A currency is any fungible financial instrument on Ethereum, including Ether and all ERC20 tokens.
 *
 * The only instance of the base class `Currency` is Ether.
 */
export abstract class BaseCurrency<T extends string = string> {
  public abstract readonly isEther: boolean
  public abstract readonly isToken: boolean

  public readonly decimals: number
  public readonly symbol: T
  public readonly name?: string

  /**
   * Constructs an instance of the base class `Currency`. The only instance of the base class `Currency` is `Currency.DOGECHAIN`.
   * @param decimals decimals of the currency
   * @param symbol symbol of the currency
   * @param name of the currency
   */
  protected constructor(decimals: number, symbol: T, name?: string) {
    invariant(decimals >= 0 && decimals < 255 && Number.isInteger(decimals), 'DECIMALS')

    this.decimals = decimals
    this.symbol = symbol
    this.name = name
  }
}
