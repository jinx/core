package family;

public abstract class DomainObject
{
    private Long identifier;

    public DomainObject()
    {
    }

    /**
     * @return the database identifier
     */
    public Long getIdentifier()
    {
        return identifier;
    }

    /**
     * @param id the id to set
     */
    public void setIdentifier(Long id)
    {
        this.identifier = id;
    }
}
